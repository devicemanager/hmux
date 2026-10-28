#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE_BYTES="${HMUX_DIFF_BENCH_BYTES:-16777216}"
ITERATIONS="${HMUX_DIFF_BENCH_ITERATIONS:-20}"
export HMUX_DIFF_BENCH_MAX_MANIFEST_P95_US="${HMUX_DIFF_BENCH_MAX_MANIFEST_P95_US:-1000}"
export HMUX_DIFF_BENCH_MIN_READ_MIBPS="${HMUX_DIFF_BENCH_MIN_READ_MIBPS:-500}"
export HMUX_DIFF_BENCH_MAX_STREAM_P95_MS="${HMUX_DIFF_BENCH_MAX_STREAM_P95_MS:-250}"

"${ROOT}/scripts/run-diff-sidecar-cargo.sh" run \
  --quiet \
  --release \
  --locked \
  --manifest-path "${ROOT}/Native/DiffSidecar/Cargo.toml" \
  --bin hmux-diff-sidecar \
  --features benchmark \
  -- benchmark "$SAMPLE_BYTES" "$ITERATIONS"

(
  cd "${ROOT}/webviews"
  HMUX_DIFF_BENCH_ITERATIONS="${HMUX_DIFF_WEB_BENCH_ITERATIONS:-5}" \
    HMUX_DIFF_BENCH_RENDER_APP="${HMUX_DIFF_BENCH_RENDER_APP:-1}" \
    bun run benchmark
)
