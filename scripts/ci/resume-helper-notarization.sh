#!/usr/bin/env bash
# Finish a recovered Computer Use submission, then create and resume the exact
# outer DMG submission and the DMG around the stapled app after it
# (resume-stapled-app-notarization.sh). The helper state and signed app must
# come from one nightly recovery artifact.
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "usage: resume-helper-notarization.sh <helper-state> <signed-app> <release-dmg> <immutable-dmg> <app-entitlements> <signing-identity> <outer-state>" >&2
  exit 2
fi

HELPER_STATE="$1"
APP_PATH="$2"
DMG_RELEASE="$3"
DMG_IMMUTABLE="$4"
APP_ENTITLEMENTS="$5"
SIGNING_IDENTITY="$6"
OUTER_STATE="$7"
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
HELPER_TOOL="${HMUX_NOTARIZE_COMPUTER_USE_HELPER_TOOL:-$ROOT_DIR/scripts/ci/notarize-computer-use-helper.sh}"
PACKAGE_TOOL="${HMUX_NOTARIZE_NIGHTLY_DMG_TOOL:-$ROOT_DIR/scripts/ci/notarize-nightly-dmg.sh}"
SIGNING_KEYCHAIN_TOOL="${HMUX_SIGNING_KEYCHAIN_TOOL:-$ROOT_DIR/scripts/ci/signing-keychain.sh}"

[ -f "$HELPER_STATE" ] || { echo "Computer Use helper state not found: $HELPER_STATE" >&2; exit 1; }
[ -d "$APP_PATH/Contents" ] || { echo "Recovered signed app not found: $APP_PATH" >&2; exit 1; }
[ -f "$APP_ENTITLEMENTS" ] || { echo "App entitlements not found: $APP_ENTITLEMENTS" >&2; exit 1; }

# The outer DMG around the helper-finished app is the first DMG of
# resume-stapled-app-notarization.sh: its state is <outer-state>.first, and the
# DMG around the stapled app that follows has <outer-state> (stapled_app=true).
FIRST_STATE="${OUTER_STATE}.first"
FIRST_LOG="${FIRST_STATE}.log"
STAPLED_TOOL="${HMUX_RESUME_STAPLED_APP_TOOL:-$ROOT_DIR/scripts/ci/resume-stapled-app-notarization.sh}"

# The Ubuntu poll job admitted this exact helper submission only after Apple
# reported Accepted. The short wait here is a final race check before stapling;
# it never submits a second helper archive. The certificate goes only to the
# stapled-app step, which makes its own keychain.
env -u APPLE_CERTIFICATE_BASE64 -u APPLE_CERTIFICATE_PASSWORD \
HMUX_HELPER_WAIT_TIMEOUT="${HMUX_HELPER_WAIT_TIMEOUT:-5m}" \
HMUX_HELPER_NOTARY_OUTPUT_FILE="${HMUX_HELPER_NOTARY_OUTPUT_FILE:-${HELPER_STATE}.log}" \
HMUX_APP_ENTITLEMENTS="$APP_ENTITLEMENTS" \
  "$HELPER_TOOL" --finish "$HELPER_STATE" "$APP_PATH" "$APP_ENTITLEMENTS" "$SIGNING_IDENTITY"

# Helper stapling changes the host resource seal, so package and submit the
# outer DMG only after helper finish.
rm -f "$FIRST_STATE" "$FIRST_LOG" "$OUTER_STATE" "$OUTER_STATE.log"
env -u APPLE_CERTIFICATE_BASE64 -u APPLE_CERTIFICATE_PASSWORD \
HMUX_STAPLE_APP_IN_DMG=false \
HMUX_COMPUTER_USE_HELPER_ALREADY_FINISHED=true \
HMUX_COMPUTER_USE_NOTARY_SUBMISSION_FILE= \
HMUX_NOTARY_SUBMIT_ONLY=true \
HMUX_SKIP_NOTARY_LOG=true \
HMUX_NOTARY_SUBMISSION_FILE="$FIRST_STATE" \
HMUX_NOTARY_OUTPUT_FILE="$FIRST_LOG" \
HMUX_APP_ENTITLEMENTS="$APP_ENTITLEMENTS" \
CHANNEL_RELEASE_TAG="${CHANNEL_RELEASE_TAG:-${HMUX_CHANNEL:-nightly}}" \
CHANNEL_DMG_PREFIX="${CHANNEL_DMG_PREFIX:-hmux-${HMUX_CHANNEL:-nightly}-macos}" \
NIGHTLY_VARIANT="${NIGHTLY_VARIANT:-universal}" \
  "$PACKAGE_TOOL" "$APP_PATH" "$DMG_RELEASE" "$DMG_IMMUTABLE"

# The package tool already deleted the CI signing keychain after the DMG
# signature. Delete again before the continuation checks the stapled app.
"$SIGNING_KEYCHAIN_TOOL" delete

[ -f "$FIRST_STATE" ] || { echo "Outer DMG notarization state was not created: $FIRST_STATE" >&2; exit 1; }
[ -s "$FIRST_LOG" ] || { echo "Outer DMG notarization evidence was not created: $FIRST_LOG" >&2; exit 1; }

# Wait for the outer DMG, staple the app, then submit and wait for the DMG
# around the stapled app (the one that ships).
# The helper finish above checked the helper; the continuation does not again.
HMUX_SKIP_HELPER_RECHECK=true \
HMUX_NOTARY_WAIT_TIMEOUT="${HMUX_OUTER_NOTARY_WAIT_TIMEOUT:-60m}" \
HMUX_NOTARY_EVIDENCE_FILE="$FIRST_LOG" \
APPLE_SIGNING_IDENTITY="$SIGNING_IDENTITY" \
  "$STAPLED_TOOL" "$FIRST_STATE" "$APP_PATH" "$DMG_RELEASE" "$DMG_IMMUTABLE" "$APP_ENTITLEMENTS" "$OUTER_STATE"
