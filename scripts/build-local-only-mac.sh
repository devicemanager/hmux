#!/usr/bin/env bash
# Build, sign, notarize and install a local-only cmux for macOS.
#
# A local-only build keeps to your own machines: it has no cmux account,
# Cloud, Iroh relays, device discovery, auto-update or telemetry, and iPhones
# pair with it over Tailscale using one-time local pairing codes (see
# ios/scripts/build-local-only.sh for the matching iPhone app). The app reads
# `CMUXLocalOnly = YES` from its Info.plist and enforces those managed-device
# policies itself (ManagedDevicePolicy.localOnlyEnforcedKeys).
#
# It installs under its own name and bundle ID, never over the official
# com.cmuxterm.app.
#
# Settings come from .env-local in the repository root (copy
# .env-local.template): team, bundle prefix, app name, Developer ID identity,
# notarytool keychain profile and install folder.
#
# Usage: scripts/build-local-only-mac.sh [--no-install] [--no-notarize] [--skip-build]
#
# --skip-build re-signs, notarizes and installs the last Release build instead
# of compiling again.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
# shellcheck source=lib/local-only-env.sh
source "$REPO_DIR/scripts/lib/local-only-env.sh"
cmux_local_only_load_env "$REPO_DIR"

INSTALL=1
NOTARIZE=1
BUILD=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-install) INSTALL=0; shift ;;
    --no-notarize) NOTARIZE=0; shift ;;
    --skip-build) BUILD=0; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

TEAM_ID="$CMUX_LOCAL_TEAM_ID"
BUNDLE_ID="$CMUX_LOCAL_MAC_BUNDLE_ID"
APP_NAME="${CMUX_LOCAL_MAC_APP_NAME:-hmux}"
INSTALL_DIR="${CMUX_LOCAL_MAC_INSTALL_DIR:-}"
NOTARY_PROFILE="${CMUX_LOCAL_NOTARY_PROFILE:-}"
[[ -n "$INSTALL_DIR" ]] || INSTALL=0
[[ -n "$NOTARY_PROFILE" ]] || NOTARIZE=0

IDENTITY="${CMUX_LOCAL_MAC_SIGNING_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning \
    | sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\"/\1/p" | head -1)"
fi
[[ -n "$IDENTITY" ]] || { echo "error: no Developer ID Application identity for team $TEAM_ID in the keychain" >&2; exit 1; }
security find-identity -v -p codesigning | grep -qF "$IDENTITY" \
  || { echo "error: signing identity not in the keychain: $IDENTITY" >&2; exit 1; }

echo "==> $APP_NAME ($BUNDLE_ID), signed by $IDENTITY"

DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/cmux-local-only-mac"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/cmux.app"
OUT_DIR="$DERIVED_DATA/LocalOnly"
APP="$OUT_DIR/$APP_NAME.app"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# --- Build ---------------------------------------------------------------
if [[ "$BUILD" -eq 1 ]]; then
./scripts/ensure-ghosttykit.sh
CMUX_SKIP_ZIG_BUILD=1 xcodebuild \
  -scheme cmux \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'generic/platform=macOS' \
  ARCHS="$(uname -m)" \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
fi
[[ -d "$BUILT_APP" ]] || { echo "error: built app not found" >&2; exit 1; }

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
ditto "$BUILT_APP" "$APP"

# The Ghostty CLI helper (`ghostty +list-themes`, the theme picker) is a
# separate zig build; the Xcode build above leaves a stub in its place.
if ./scripts/build-ghostty-cli-helper.sh --target "$(uname -m | sed 's/arm64/aarch64/')-macos" \
     --output "$WORK_DIR/ghostty"; then
  install -m 0755 "$WORK_DIR/ghostty" "$APP/Contents/Resources/bin/ghostty"
else
  echo "warning: Ghostty CLI helper build failed; the theme picker stays unavailable" >&2
fi

# --- Identity and local-only switch --------------------------------------
PLIST="$APP/Contents/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$PLIST"; }
pb "Set :CFBundleName $APP_NAME"
pb "Delete :CFBundleDisplayName" 2>/dev/null || true
pb "Add :CFBundleDisplayName string $APP_NAME"
pb "Set :CFBundleIdentifier $BUNDLE_ID"
# URL types keep the official app's ordering: web, auth, ssh. The auth scheme
# must not claim the official app's callback.
for index in 0 1 2; do
  name="$(pb "Print :CFBundleURLTypes:$index:CFBundleURLName" 2>/dev/null || true)"
  case "$name" in
    *.web) pb "Set :CFBundleURLTypes:$index:CFBundleURLName $BUNDLE_ID.web" ;;
    *.auth)
      pb "Set :CFBundleURLTypes:$index:CFBundleURLName $BUNDLE_ID.auth"
      pb "Set :CFBundleURLTypes:$index:CFBundleURLSchemes:0 ${BUNDLE_ID//./-}-auth"
      ;;
  esac
done
for key in SUFeedURL SUPublicEDKey CMUXLocalOnly CMUXCommit; do
  pb "Delete :$key" 2>/dev/null || true
done
pb "Set :SUEnableAutomaticChecks false" 2>/dev/null || pb "Add :SUEnableAutomaticChecks bool false"
pb "Set :SUAutomaticallyUpdate false" 2>/dev/null || pb "Add :SUAutomaticallyUpdate bool false"
pb "Add :CMUXLocalOnly string YES"
pb "Add :CMUXCommit string $(git rev-parse --short HEAD)"

# --- Sign ----------------------------------------------------------------
# The app keeps secrets (session encryption key, CLI socket credential) in its
# own Keychain group, which a Developer ID app may claim only when an embedded
# provisioning profile grants it; otherwise macOS refuses to spawn it (POSIX
# error 163). With App Store Connect API credentials the profile is created or
# reused in your account. Without them the group is dropped and those secrets
# cannot be stored. The official app's group and the browser passkey
# entitlement are never claimed. The signer also removes the Cloud tunnel
# system extension.
ENTITLEMENTS="$WORK_DIR/cmux-local-only.entitlements"
cp cmux.entitlements "$ENTITLEMENTS"
ent() { /usr/libexec/PlistBuddy -c "$1" "$ENTITLEMENTS"; }
for key in keychain-access-groups com.apple.developer.web-browser.public-key-credential; do
  ent "Delete :$key" 2>/dev/null || true
done
if [[ -n "${CMUX_LOCAL_ASC_KEY_ID:-}" && -n "${CMUX_LOCAL_ASC_ISSUER_ID:-}" && -n "${CMUX_LOCAL_ASC_KEY_PATH:-}" ]]; then
  identity_sha1="$(security find-identity -v -p codesigning | grep -F "$IDENTITY" | awk '{print $2}' | head -1)"
  [[ -n "$identity_sha1" ]] || { echo "error: cannot resolve the certificate hash of $IDENTITY" >&2; exit 1; }
  ASC_API_KEY_ID="$CMUX_LOCAL_ASC_KEY_ID" \
  ASC_API_ISSUER_ID="$CMUX_LOCAL_ASC_ISSUER_ID" \
  ASC_API_KEY_PATH="${CMUX_LOCAL_ASC_KEY_PATH/#\~/$HOME}" \
    python3 scripts/local-only-mac-profile.py \
      --bundle-id "$BUNDLE_ID" \
      --app-name "$APP_NAME" \
      --identity-sha1 "$identity_sha1" \
      --output "$APP/Contents/embedded.provisionprofile"
  ent "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID"
  ent "Add :com.apple.developer.team-identifier string $TEAM_ID"
  ent "Add :keychain-access-groups array"
  ent "Add :keychain-access-groups:0 string $TEAM_ID.$BUNDLE_ID"
else
  echo "warning: no App Store Connect credentials; signing without a Keychain group" >&2
  if grep -q "com.apple.developer\|keychain-access-groups" "$ENTITLEMENTS"; then
    echo "error: entitlements claim a profile-only entitlement but no profile is embedded" >&2
    exit 1
  fi
fi
CMUX_SIGN_MODE=all ./scripts/sign-cmux-bundle.sh "$APP" "$ENTITLEMENTS" "$IDENTITY"
if [[ -d "$APP/Contents/Library/SystemExtensions" ]]; then
  echo "error: the local-only app must not carry the Cloud tunnel extension" >&2
  exit 1
fi

# --- Notarize --------------------------------------------------------------
if [[ "$NOTARIZE" -eq 1 ]]; then
  echo "==> Notarizing with keychain profile $NOTARY_PROFILE"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK_DIR/notary.zip"
  xcrun notarytool submit "$WORK_DIR/notary.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
else
  echo "==> Skipping notarization"
fi
echo "==> Built $APP_NAME"

# --- Install ---------------------------------------------------------------
if [[ "$INSTALL" -eq 0 ]]; then
  exit 0
fi
DEST="$INSTALL_DIR/$APP_NAME.app"
# A rename leaves the previous copy under its old name; remove it so only one
# app carries this bundle ID.
for old in "$INSTALL_DIR"/*.app; do
  [[ -d "$old" && "$old" != "$DEST" ]] || continue
  old_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$old/Contents/Info.plist" 2>/dev/null || true)"
  [[ "$old_id" == "$BUNDLE_ID" ]] || continue
  if pgrep -f "^$old/Contents/MacOS/" >/dev/null; then
    echo "error: $(basename "$old" .app) is running. Quit it, then rerun to install." >&2
    exit 1
  fi
  echo "==> Removing $old (renamed to $APP_NAME)"
  rm -rf "$old"
done
if [[ -d "$DEST" ]]; then
  existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$existing_id" != "$BUNDLE_ID" ]]; then
    echo "error: $DEST belongs to $existing_id, not this build; refusing to replace it" >&2
    exit 1
  fi
  if pgrep -f "^$DEST/Contents/MacOS/" >/dev/null; then
    echo "error: $APP_NAME is running. Quit it, then rerun to install." >&2
    exit 1
  fi
  rm -rf "$DEST"
fi
ditto "$APP" "$DEST"
echo "==> Installed $APP_NAME in $INSTALL_DIR"
