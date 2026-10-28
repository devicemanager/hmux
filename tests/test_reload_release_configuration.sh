#!/usr/bin/env bash
# Regression test: reload.sh only built the Debug configuration, so every fleet
# dogfood build (hmux-ci build hmux, with or without --production) was -Onone with
# DEBUG defined, and perf impressions came from unoptimized code. --release builds
# the Release configuration of the same tagged app: the same tagged bundle id, the
# checkout's own hmux-tui (tree mode, not Release's pinned default), no Release
# entitlements on the ad hoc signed app, and products read from Build/Products/Release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELOAD="$ROOT_DIR/scripts/reload.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
TAG="release-probe-$$"
LOCK_FILE="$(python3 -c 'import os, sys, tempfile; print(os.path.join(tempfile.gettempdir(), "hmux-reload-tags-%d" % os.getuid(), sys.argv[1] + ".lock"))' "$TAG")"
cleanup() {
  rm -rf "$TMP_DIR"
  rm -f "/tmp/hmux-reload-${TAG}.log" "$LOCK_FILE"
}
trap cleanup EXIT

# A scratch checkout whose build steps are stubs. The xcodebuild stub records its
# arguments and the hmux-tui mode it was given, then fails, so no run goes past it.
CHECKOUT="$TMP_DIR/checkout"
ARGS="$TMP_DIR/xcodebuild-args"
mkdir -p "$CHECKOUT/scripts/lib" "$TMP_DIR/bin"
ln -s "$ROOT_DIR/scripts/lib/dev-backend-origin.sh" "$CHECKOUT/scripts/lib/dev-backend-origin.sh"
for stub in dev-backend.sh ensure-ghosttykit.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$CHECKOUT/scripts/$stub"
  chmod +x "$CHECKOUT/scripts/$stub"
done
cat > "$TMP_DIR/bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == -version ]] && { echo "Xcode 26.6"; exit 0; }
{ printf 'tui-mode=%s\n' "${HMUX_NEXT_TUI_MODE-unset}"; printf '%s\n' "$@"; } > "$STUB_ARGS"
exit 3
STUB
chmod +x "$TMP_DIR/bin/xcodebuild"

OUTPUT=""
run_reload() {
  rm -f "$ARGS"
  set +e
  OUTPUT="$(cd "$CHECKOUT" && env \
    -u HMUX_TUI_CLIENT_LOCAL -u HMUX_TUI_CLIENT_MANIFEST_URL -u HMUX_SOURCE_PACKAGES_DIR \
    -u HMUX_DERIVED_DATA -u HMUX_RELOAD_TAG_LOCK_OWNER -u HMUX_DEV_BACKEND_URL \
    PATH="$TMP_DIR/bin:$PATH" STUB_ARGS="$ARGS" HMUX_SKIP_HMUX_TUI_CLIENT=1 \
    HMUX_DEV_BACKEND_MODE=local HMUX_NEXT_TUI_MODE=pin \
    HMUX_NEXT_TUI_BIN="$TMP_DIR/hmux-tui" HMUX_NEXT_ACPMUX_BIN="$TMP_DIR/acpmux" \
    "$RELOAD" "$@" 2>&1)"
  STATUS=$?
  set -e
}
arg_after() { awk -v key="$1" 'found { print; exit } $0 == key { found = 1 }' "$ARGS"; }

run_reload --tag "$TAG" --build-only --derived-data "$TMP_DIR/dd" --release
[[ -f "$ARGS" ]] || fail "--release never reached xcodebuild: $OUTPUT"
[[ "$(arg_after -configuration)" == Release ]] \
  || fail "--release built configuration '$(arg_after -configuration)', not Release"
grep -qx "PRODUCT_BUNDLE_IDENTIFIER=com.hmuxterm.app.debug.${TAG//-/.}" "$ARGS" \
  || fail "--release did not keep the tagged debug bundle id: $(grep PRODUCT_BUNDLE_IDENTIFIER "$ARGS")"
grep -qx 'CODE_SIGN_ENTITLEMENTS=' "$ARGS" \
  || fail "--release kept the Release entitlements on an ad hoc signed tagged app"
grep -qx 'tui-mode=tree' "$ARGS" \
  || fail "--release did not force the checkout's own hmux-tui: $(head -n 1 "$ARGS")"
echo "PASS: --release builds the tagged app in Release with tree-mode hmux-tui and no Release entitlements"

run_reload --tag "$TAG" --build-only --derived-data "$TMP_DIR/dd"
[[ -f "$ARGS" ]] || fail "the default reload never reached xcodebuild: $OUTPUT"
[[ "$(arg_after -configuration)" == Debug ]] || fail "the default reload no longer builds Debug"
grep -qx 'tui-mode=pin' "$ARGS" || fail "the default reload overrode the caller's HMUX_NEXT_TUI_MODE"
! grep -qx 'CODE_SIGN_ENTITLEMENTS=' "$ARGS" || fail "the default reload changed entitlements"
echo "PASS: without --release the reload still builds Debug and leaves the hmux-tui mode alone"

# The product directory and source app name follow the configuration: Release's
# product is hmux.app, which the tag step renames to the tagged app.
products="$(awk '/^[[:space:]]*BUILD_PRODUCTS_DEBUG_DIR=.*Build\/Products/ { print; exit }' "$RELOAD")"
[[ "$products" == *'$BUILD_CONFIGURATION'* || "$products" == *'${BUILD_CONFIGURATION}'* ]] \
  || fail "reload.sh still reads products from a fixed directory: $products"
echo "PASS: products are read from the built configuration's directory"
