#!/usr/bin/env bash
# Publish the notarized local-only Mac app as a GitHub release.
#
# Packs the app that scripts/build-local-only-mac.sh last built into a DMG,
# signs and notarizes the DMG, and attaches it to a release in
# HMUX_LOCAL_RELEASE_REPO (owner/name, from .env-local). The release is tagged
# v<version>-<commit>, so republishing the same build fails instead of
# overwriting it.
#
# Usage: scripts/publish-local-only-mac.sh [--draft] [--no-upload]
#
# --draft      create the release as a draft
# --no-upload  build and notarize the DMG only
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
# shellcheck source=lib/local-only-env.sh
source "$REPO_DIR/scripts/lib/local-only-env.sh"
hmux_local_only_load_env "$REPO_DIR"

DRAFT=()
UPLOAD=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft) DRAFT=(--draft); shift ;;
    --no-upload) UPLOAD=0; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
done

TEAM_ID="$HMUX_LOCAL_TEAM_ID"
APP_NAME="${HMUX_LOCAL_MAC_APP_NAME:-hmux}"
NOTARY_PROFILE="${HMUX_LOCAL_NOTARY_PROFILE:-}"
RELEASE_REPO="${HMUX_LOCAL_RELEASE_REPO:-}"
[[ -n "$NOTARY_PROFILE" ]] || { echo "error: set HMUX_LOCAL_NOTARY_PROFILE; a published app must be notarized" >&2; exit 1; }
[[ "$UPLOAD" -eq 0 || -n "$RELEASE_REPO" ]] || { echo "error: set HMUX_LOCAL_RELEASE_REPO (owner/name)" >&2; exit 1; }

APP="$HOME/Library/Developer/Xcode/DerivedData/hmux-local-only-mac/LocalOnly/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "error: $APP not found; run scripts/build-local-only-mac.sh first" >&2; exit 1; }
# Only a build that went through notarization is published.
xcrun stapler validate "$APP" >/dev/null \
  || { echo "error: $APP is not notarized; rerun scripts/build-local-only-mac.sh with a notary profile" >&2; exit 1; }

IDENTITY="${HMUX_LOCAL_MAC_SIGNING_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning \
    | sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\"/\1/p" | head -1)"
fi
[[ -n "$IDENTITY" ]] || { echo "error: no Developer ID Application identity for team $TEAM_ID in the keychain" >&2; exit 1; }

PLIST="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
COMMIT="$(/usr/libexec/PlistBuddy -c 'Print :HMUXCommit' "$PLIST")"
TAG="v$VERSION-$COMMIT"

OUT_DIR="$(dirname "$APP")/Release"
DMG="$OUT_DIR/$APP_NAME-$VERSION-$COMMIT.dmg"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> $APP_NAME $VERSION ($BUILD), commit $COMMIT"
mkdir -p "$OUT_DIR" "$WORK_DIR/dmg"
rm -f "$DMG"
ditto "$APP" "$WORK_DIR/dmg/$APP_NAME.app"
ln -s /Applications "$WORK_DIR/dmg/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$WORK_DIR/dmg" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing $(basename "$DMG")"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "==> $DMG"
echo "    sha256 $SHA256"

if [[ "$UPLOAD" -eq 0 ]]; then
  exit 0
fi

NOTES="$WORK_DIR/notes.md"
cat > "$NOTES" <<EOF
$APP_NAME $VERSION (build $BUILD), built from commit \`$COMMIT\`.

Open the DMG and drag $APP_NAME to Applications. Requires macOS 14 or later.
The app is signed with a Developer ID and notarized by Apple.

SHA-256 of \`$(basename "$DMG")\`: \`$SHA256\`
EOF
# The tag points at the built commit; push that commit to the repo first.
gh release create "$TAG" "$DMG" --repo "$RELEASE_REPO" --target "$(git rev-parse "$COMMIT")" --title "$APP_NAME $VERSION ($COMMIT)" \
  --notes-file "$NOTES" ${DRAFT[@]+"${DRAFT[@]}"}
echo "==> Published $TAG to $RELEASE_REPO"
