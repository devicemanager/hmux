#!/usr/bin/env bash
set -euo pipefail

# Fail-closed artifact gate for every signed/unsigned iOS Release archive.
# TestFlight and App Store builds use the production Stack project and must
# carry only production API, Iroh broker, and presence origins. This checks the
# built Info.plist, rather than the source settings, so an accidental CI
# environment override cannot reach an upload.

usage() {
  cat <<'EOF'
Usage: scripts/lib/verify-ios-release-origins.sh --app <path>
EOF
}

APP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$APP" ]] || { echo "error: --app is required" >&2; exit 2; }
[[ -d "$APP" ]] || { echo "error: iOS app does not exist: $APP" >&2; exit 1; }
PLIST="$APP/Info.plist"
[[ -f "$PLIST" ]] || { echo "error: iOS app Info.plist is missing: $PLIST" >&2; exit 1; }

read_plist() {
  local key="$1"
  if [[ -x /usr/libexec/PlistBuddy ]]; then
    # Keep release verification tied to Apple's system tool. Do not honor an
    # environment override here, because that would let a caller replace the
    # verifier and bypass this gate.
    /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" 2>/dev/null || true
    return
  fi

  # Linux CI does not provide PlistBuddy. Use the fixed system Python parser
  # only for that environment; production macOS always takes the branch above.
  /usr/bin/python3 - "$PLIST" "$key" <<'PY' 2>/dev/null || true
import plistlib
import sys

with open(sys.argv[1], "rb") as stream:
    value = plistlib.load(stream)
for component in sys.argv[2].split(":"):
    value = value[component]
if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (dict, list)):
    print(plistlib.dumps(value, fmt=plistlib.FMT_XML).decode(), end="")
else:
    print(value)
PY
}

require_exact() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: production iOS artifact $label is '${actual:-<absent>}', expected '$expected'; refusing to ship staging content" >&2
    return 1
  fi
}

require_empty() {
  local label="$1"
  local actual="$2"
  if [[ -n "$actual" ]]; then
    echo "error: production iOS artifact $label is '$actual'; release artifacts cannot carry a development tag" >&2
    return 1
  fi
}

bundle_id="$(read_plist CFBundleIdentifier)"
case "$bundle_id" in
  com.hmux.app|com.hmuxterm.app.nightly|dev.hmux.app.beta|dev.hmux.app.internal|dev.hmux.app.demo) ;;
  *)
    echo "error: production iOS artifact has unexpected release bundle identifier '${bundle_id:-<absent>}'" >&2
    exit 1
    ;;
esac
require_exact "HMUXAuthEnvironment" "$(read_plist HMUXAuthEnvironment)" "production"
require_exact "HMUXApiBaseURL" "$(read_plist HMUXApiBaseURL)" "https://cmux.com"
require_exact "HMUXIrohBrokerBaseURL" "$(read_plist HMUXIrohBrokerBaseURL)" "https://cmux.com"
require_exact "HMUXPresenceBaseURL" "$(read_plist HMUXPresenceBaseURL)" "https://presence.cmux.dev"
require_empty "HMUXDevTag" "$(read_plist HMUXDevTag)"

echo "==> production iOS runtime origins verified for ${bundle_id:-unknown bundle}"
