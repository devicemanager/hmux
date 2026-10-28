#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/mobile-attach.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/hmux-readiness-receipt.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

app="$tmp/hmux.app"
mkdir -p "$app"
cat >"$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.hmux.ios.receipt-test</string>
<key>CFBundleExecutable</key><string>hmux</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>17</string>
<key>HMUXGitSHA</key><string>installed-source-sha</string>
<key>HMUXDevTag</key><string>receipt-test</string>
</dict></plist>
PLIST
printf 'installed executable bytes\n' >"$app/hmux"

metadata="$(HMUX_INSTALLED_APP_PATH="$app" \
  hmux_attach_installed_bundle_metadata \
  simulator_injection SIM-RECEIPT-TEST dev.hmux.ios.receipt-test)"
export HMUX_DEV_AUTH_PROFILE=agent
export HMUX_DEV_AUTH_ACCOUNT=receipt-test@example.com
event='{"name":"mobile.rpc.ready","payload":{"connection_id":"c","client_id":"i","stream_id":"s","transport":"iroh","workspace_count":1}}'
receipt="$tmp/receipt.json"
hmux_attach_write_readiness_receipt \
  "$receipt" tooling-checkout-sha receipt-test dev.hmux.ios.receipt-test \
  simulator_injection SIM-RECEIPT-TEST receipt-test /tmp/hmux-receipt-test.sock \
  12 1 "$event" "$metadata"

/usr/bin/python3 - "$receipt" "$app/hmux" <<'PY'
import hashlib
import json
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
expected_hash = hashlib.sha256(open(sys.argv[2], "rb").read()).hexdigest()
assert receipt["git_sha"] == "installed-source-sha"
assert receipt["tooling_checkout_sha"] == "tooling-checkout-sha"
assert receipt["installed_bundle"]["executable_sha256"] == expected_hash
assert receipt["installed_bundle"]["dev_tag"] == "receipt-test"
PY

# Existing callers that have not added the metadata argument remain valid and
# receive an explicit legacy marker instead of silently claiming a source SHA.
legacy="$tmp/legacy.json"
hmux_attach_write_readiness_receipt \
  "$legacy" tooling-sha receipt-test dev.hmux.ios.receipt-test \
  simulator_injection SIM-RECEIPT-TEST receipt-test /tmp/hmux-receipt-test.sock \
  12 1 "$event"
/usr/bin/python3 - "$legacy" <<'PY'
import json
import sys

receipt = json.load(open(sys.argv[1], encoding="utf-8"))
assert receipt["git_sha"] == "tooling-sha"
assert receipt["tooling_checkout_sha"] == "tooling-sha"
assert receipt["installed_bundle"]["source"] == "legacy_receipt_writer"
assert receipt["installed_bundle"]["executable_sha256"] is None
PY

echo "mobile readiness receipt integrity: PASS"
