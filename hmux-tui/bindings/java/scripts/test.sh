#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/build.sh"

CLASSPATH="$ROOT/build/classes:$ROOT/build/test-classes"
for test_class in \
  com.hmux.raw.CodecTest \
  com.hmux.raw.SocketDiscoveryTest \
  com.hmux.raw.GeneratedCoverageTest \
  com.hmux.raw.GeneratedModelTest \
  com.hmux.raw.StreamModeTest \
  com.hmux.raw.LifecycleTest \
  com.hmux.raw.ErgonomicsTest \
  com.hmux.internal.UnixTransportTest \
  com.hmux.ResourceApiTest \
  com.hmux.BrowserPointerFrameTest
do
  java -ea -cp "$CLASSPATH" "$test_class"
done

java -ea \
  -cp "$ROOT/build/hmux-java-sdk.jar:$ROOT/build/consumer-test-classes" \
  com.hmux.consumer.ExternalJarConsumerTest
