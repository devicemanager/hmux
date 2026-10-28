#!/usr/bin/env bash
set -euo pipefail

root="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
# shellcheck source=scripts/lib/mobile-attach.sh
source "$root/scripts/lib/mobile-attach.sh"
state="${HMUX_WORKLOAD_STATE_ROOT:?HMUX_WORKLOAD_STATE_ROOT is required}"
attempt_id="${HMUX_WORKLOAD_ATTEMPT_ID:?HMUX_WORKLOAD_ATTEMPT_ID is required}"
derived="$state/derived-data"
source_packages="$state/source-packages"
xcode_env="$state/xcode.env"
tag="profile-$attempt_id"
hmux_attach_validate_dev_tag "$tag"
tag_slug="$(hmux_attach__slug "$tag")"
expected_bundle_id="$(hmux_attach_mac_bundle_id "$tag")"

stage() {
  python3 "$root/scripts/ci/hmux_workload_profile.py" stage "$1" "$2"
}

cd "$root"
mkdir -p "$state" "$derived" "$source_packages"
export PATH="$HOME/.cargo/bin:$PATH"

stage start setup
: > "$xcode_env"
GITHUB_ENV="$xcode_env" HMUX_CI_REQUIRED_MACOS_SDK_MAJOR=26 \
  ./scripts/select-ci-xcode.sh
while IFS= read -r assignment; do
  case "$assignment" in
    DEVELOPER_DIR=*) export "$assignment" ;;
  esac
done < "$xcode_env"
./scripts/install-rust-ci.sh
./scripts/download-prebuilt-ghosttykit.sh
stage end setup

stage start compile
HMUX_DEV_BACKEND_MODE=local \
HMUX_DEV_CLOUD_ENABLED=0 \
HMUX_LOCAL_CACHE_PREFLIGHT=0 \
HMUX_GHOSTTYKIT_PREPROVISIONED=1 \
HMUX_SOURCE_PACKAGES_DIR="$source_packages" \
HMUX_RELOAD_NO_GLOBAL_CLI_LINKS=1 \
  ./scripts/reload.sh \
    --tag "$tag" \
    --derived-data "$derived" \
    --no-global-cli-links
stage end compile

stage start validation
app="$derived/Build/Products/Debug/hmux DEV $tag_slug.app"
test -x "$app/Contents/MacOS/hmux DEV"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
test "$bundle_id" = "$expected_bundle_id"
stage end validation
