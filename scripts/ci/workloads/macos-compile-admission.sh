#!/usr/bin/env bash
set -euo pipefail

root="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
state="${HMUX_WORKLOAD_STATE_ROOT:?HMUX_WORKLOAD_STATE_ROOT is required}"
derived="$state/derived-data"
source_packages="$state/source-packages"
cas="$state/xcode-compilation-cas"
log="$state/compile-admission.log"

stage() {
  python3 "$root/scripts/ci/hmux_workload_profile.py" stage "$1" "$2"
}

cd "$root"
mkdir -p "$state" "$source_packages" "$cas"
export PATH="$HOME/.cargo/bin:$PATH"

stage start setup
export HMUX_CI_REQUIRED_MACOS_SDK_MAJOR="${HMUX_CI_REQUIRED_MACOS_SDK_MAJOR:-26}"
export HMUX_SKIP_ZIG_BUILD=1
xcode_env="$state/xcode.env"
: > "$xcode_env"
GITHUB_ENV="$xcode_env" ./scripts/select-ci-xcode.sh
while IFS= read -r assignment; do
  case "$assignment" in
    DEVELOPER_DIR=*) export "$assignment" ;;
  esac
done < "$xcode_env"
./scripts/install-rust-ci.sh
# Always materialize the pinned, checksum-verified framework for this semantic
# workload. A developer/reused-worker checkout may contain ignored stale bytes.
./scripts/download-prebuilt-ghosttykit.sh
stage end setup

stage start dependency_preparation
scripts/ci/compile-app-host-test-product.sh resolve "$derived" "$source_packages"
stage end dependency_preparation

stage start compile
scripts/ci/compile-app-host-test-product.sh build   "$derived" "$source_packages" "$cas" "$log"
stage end compile

stage start validation
python3 scripts/swift_warning_budget.py --log "$derived/hmux-build.log"
find "$derived/Build/Products" -type f -name '*.xctestrun' -print -quit | grep -q .
test -x "$derived/Build/Products/Debug/hmux"
stage end validation
