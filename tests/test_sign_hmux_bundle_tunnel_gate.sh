#!/usr/bin/env bash
# Release signing must fail before codesign when the desired tunnel capability
# is absent from the app's embedded provisioning profile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

APP="$TMP_DIR/hmux.app"
mkdir -p "$APP/Contents"

if "$ROOT/scripts/sign-hmux-bundle.sh" \
  "$APP" \
  "$ROOT/hmux.release.entitlements" \
  "Developer ID Application: Test" >"$TMP_DIR/out" 2>"$TMP_DIR/err"; then
  echo "FAIL: release signing accepted an app with no provisioning profile" >&2
  exit 1
fi

grep -q "app entitlements require the Cloud tunnel" "$TMP_DIR/err" || {
  echo "FAIL: signing did not fail at the Cloud tunnel profile gate" >&2
  sed -n '1,120p' "$TMP_DIR/err" >&2
  exit 1
}

echo "PASS: sign-hmux-bundle.sh tunnel gate"
