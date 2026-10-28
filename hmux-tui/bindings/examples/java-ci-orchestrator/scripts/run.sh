#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINDINGS_ROOT="$(cd "$ROOT/../.." && pwd)"
SDK_ROOT="$BINDINGS_ROOT/java"

"$ROOT/scripts/build.sh"

SDK_JAR="${HMUX_JAVA_SDK_JAR:-$SDK_ROOT/build/hmux-java-sdk.jar}"
exec java \
  -cp "$SDK_JAR:$ROOT/build/java-ci-orchestrator.jar" \
  com.hmux.examples.ci.CiOrchestrator \
  "$@"
