#!/usr/bin/env bash
# Regression test: reload.sh resolved the published hmux-tui client only after the
# Xcode build, so a branch whose own hmux-tui commits have no published client ran
# a full build (755 s on the fleet, 2026-09-24) and then failed. The resolver must
# run before the dev backend, GhosttyKit and xcodebuild, fail fast with the
# overrides named, run once, and stay out of the way when an override supplies the
# client.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELOAD="$ROOT_DIR/scripts/reload.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
TAG="tui-resolve-probe-$$"
LOCK_FILE="$(python3 -c 'import os, sys, tempfile; print(os.path.join(tempfile.gettempdir(), "hmux-reload-tags-%d" % os.getuid(), sys.argv[1] + ".lock"))' "$TAG")"
cleanup() {
  rm -rf "$TMP_DIR"
  rm -f "/tmp/hmux-reload-${TAG}.log" "$LOCK_FILE"
}
trap cleanup EXIT

# reload.sh runs checkout scripts through $PWD, so a scratch checkout with stubs
# records which steps ran and in what order. Every stub that stands for the build
# fails, so no run gets past the first build step.
CHECKOUT="$TMP_DIR/checkout"
EVENTS="$TMP_DIR/events"
mkdir -p "$CHECKOUT/scripts/ci" "$CHECKOUT/scripts/lib" "$TMP_DIR/bin"
ln -s "$ROOT_DIR/scripts/lib/dev-backend-origin.sh" "$CHECKOUT/scripts/lib/dev-backend-origin.sh"
cat > "$CHECKOUT/scripts/ci/resolve-hmux-tui-client-commit.sh" <<'EOF'
#!/usr/bin/env bash
echo resolve >> "$STUB_EVENTS"
if [[ "$STUB_RESOLVE" == ok ]]; then
  echo "resolve-hmux-tui-client-commit: using hmux-tui commit (stub)" >&2
  printf '%s\n' 0123456789abcdef0123456789abcdef01234567
  exit 0
fi
echo "error: the newest hmux-tui commit 114eab27 has no published client (stub)" >&2
exit 1
EOF
cat > "$CHECKOUT/scripts/dev-backend.sh" <<'EOF'
#!/usr/bin/env bash
echo dev-backend >> "$STUB_EVENTS"
exit 3
EOF
cat > "$CHECKOUT/scripts/ensure-ghosttykit.sh" <<'EOF'
#!/usr/bin/env bash
echo ensure-ghosttykit >> "$STUB_EVENTS"
exit 3
EOF
cat > "$TMP_DIR/bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo xcodebuild >> "$STUB_EVENTS"
exit 3
EOF
chmod +x "$CHECKOUT/scripts/ci/resolve-hmux-tui-client-commit.sh" "$CHECKOUT/scripts/dev-backend.sh" \
  "$CHECKOUT/scripts/ensure-ghosttykit.sh" "$TMP_DIR/bin/xcodebuild"

# run <resolver mode> [env assignments...] -- [reload args...]
OUTPUT=""
run_reload() {
  local mode="$1"; shift
  local assignments=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do assignments+=("$1"); shift; done
  [[ $# -gt 0 ]] && shift
  : > "$EVENTS"
  set +e
  OUTPUT="$(cd "$CHECKOUT" && env \
    -u HMUX_TUI_CLIENT_LOCAL -u HMUX_TUI_CLIENT_MANIFEST_URL -u HMUX_SKIP_HMUX_TUI_CLIENT \
    -u HMUX_GHOSTTYKIT_PREPROVISIONED -u HMUX_SOURCE_PACKAGES_DIR -u HMUX_DERIVED_DATA \
    -u HMUX_RELOAD_TAG_LOCK_OWNER -u HMUX_DEV_BACKEND_URL \
    PATH="$TMP_DIR/bin:$PATH" STUB_EVENTS="$EVENTS" STUB_RESOLVE="$mode" \
    HMUX_DEV_BACKEND_MODE=local ${assignments[@]+"${assignments[@]}"} \
    "$RELOAD" --tag "$TAG" --build-only --derived-data "$TMP_DIR/dd" "$@" 2>&1)"
  STATUS=$?
  set -e
}
events() { tr '\n' ' ' < "$EVENTS" | sed 's/ $//'; }

# No published client: fail before any build step, once, naming the overrides.
run_reload fail --
[[ "$STATUS" -ne 0 ]] || fail "reload succeeded without a published hmux-tui client"
[[ "$(events)" == "resolve" ]] \
  || fail "expected only the resolver to run before failing, got: $(events)"
[[ "$OUTPUT" == *"has no published client (stub)"* ]] \
  || fail "the resolver's own error was not shown: $OUTPUT"
[[ "$OUTPUT" == *"HMUX_TUI_CLIENT_LOCAL="* && "$OUTPUT" == *"--hmux-tui-manifest-url"* ]] \
  || fail "the early error does not name the hmux-tui client overrides: $OUTPUT"
echo "PASS: a missing published hmux-tui client fails before GhosttyKit and xcodebuild"

# Published client: resolved exactly once, before the first build step.
run_reload ok --
[[ "$(events)" == "resolve ensure-ghosttykit" ]] \
  || fail "expected one resolve before the build, got: $(events)"
before_start="${OUTPUT%%==> reload starting*}"
[[ "$before_start" != "$OUTPUT" ]] || fail "reload never reached its start line: $OUTPUT"
[[ "$before_start" != *"using hmux-tui commit"* && "$OUTPUT" == *"using hmux-tui commit (stub)"* ]] \
  || fail "a successful resolve must log to the reload log, not print before it: $OUTPUT"
echo "PASS: the hmux-tui client commit is resolved once, before the build, and logs quietly"

# The shared dev backend (remote mode) starts only after the client resolves.
run_reload fail HMUX_DEV_BACKEND_MODE=remote --
[[ "$STATUS" -ne 0 && "$(events)" == "resolve" ]] \
  || fail "a missing client must fail before the shared dev backend starts, got: $(events)"
run_reload ok HMUX_DEV_BACKEND_MODE=remote --
[[ "$(events)" == "resolve dev-backend" ]] \
  || fail "expected the resolve before the shared dev backend, got: $(events)"
echo "PASS: the hmux-tui client resolves before the shared dev backend starts"

# Overrides supply the client, so nothing is resolved (today's behavior).
for override in "HMUX_TUI_CLIENT_LOCAL=$TMP_DIR/hmux-tui" \
    "HMUX_TUI_CLIENT_MANIFEST_URL=https://files.cmux.com/cmux-tui/x/manifest.json" \
    "HMUX_SKIP_HMUX_TUI_CLIENT=1"; do
  run_reload fail "$override" --
  [[ "$(events)" == "ensure-ghosttykit" ]] \
    || fail "${override%%=*} should skip the early resolve, got: $(events)"
done
run_reload fail -- --hmux-tui-manifest-url "https://files.cmux.com/cmux-tui/x/manifest.json"
[[ "$(events)" == "ensure-ghosttykit" ]] \
  || fail "--hmux-tui-manifest-url should skip the early resolve, got: $(events)"
echo "PASS: HMUX_TUI_CLIENT_LOCAL, HMUX_TUI_CLIENT_MANIFEST_URL, --hmux-tui-manifest-url and HMUX_SKIP_HMUX_TUI_CLIENT skip it"

# The install step reuses the early commit and resolves only when it was deferred.
[[ "$(grep -c 'scripts/ci/resolve-hmux-tui-client-commit.sh' "$RELOAD")" -eq 1 ]] \
  || fail "reload.sh must call the resolver from one place"
awk '
  /if \[\[ -z "\$HMUX_TUI_CLIENT_COMMIT" \]\]; then/ { guarded = 1; next }
  guarded && /HMUX_TUI_CLIENT_COMMIT="\$\(resolve_hmux_tui_client_commit\)"/ { late = 1 }
  guarded && /^    fi$/ { guarded = 0 }
  /--expected-commit "\$HMUX_TUI_CLIENT_COMMIT"/ { reused = 1 }
  END { exit (late && reused) ? 0 : 1 }
' "$RELOAD" || fail "the install step must reuse HMUX_TUI_CLIENT_COMMIT and resolve only when it is empty"
echo "PASS: the install step reuses the resolved commit"
