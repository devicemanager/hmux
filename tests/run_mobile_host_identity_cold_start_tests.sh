#!/bin/bash
# Run only on a disposable/leased Mac or hosted CI, never the user's shared Mac.
# Compile production identity/migration and atomics; stub only display/tag metadata.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:?pass an isolated scratch directory}
mkdir -p "$DEST/Sources/IdentityColdStartFixture" "$DEST/Sources/HMUXMobileCore" \
  "$DEST/Sources/HmuxSettings" "$DEST/Sources/HmuxFoundation" \
  "$DEST/Sources/HmuxFoundationAtomicsC/include"
cat > "$DEST/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "IdentityColdStartFixture",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HMUXMobileCore"),
        .target(name: "HmuxSettings"),
        .target(name: "HmuxFoundationAtomicsC", publicHeadersPath: "include"),
        .target(name: "HmuxFoundation", dependencies: ["HmuxFoundationAtomicsC"]),
        .executableTarget(
            name: "IdentityColdStartFixture",
            dependencies: ["HMUXMobileCore", "HmuxSettings", "HmuxFoundation"]
        )
    ],
    swiftLanguageModes: [.v5]
)
SWIFT
cp "$ROOT/Packages/macOS/HmuxCloud/Sources/HmuxCloud/Environment/MobileHostIdentity.swift" "$DEST/Sources/IdentityColdStartFixture/"
cp "$ROOT/tests/fixtures/mobile-host-identity-cold-start/IdentityColdStartFixture.swift" \
  "$ROOT/tests/fixtures/mobile-host-identity-cold-start/IdentityNotificationProbe.swift" \
  "$DEST/Sources/IdentityColdStartFixture/"
cp "$ROOT/Packages/Shared/HMUXMobileCore/Sources/HMUXMobileCore/CmxDeviceIDCanonicalization.swift" \
  "$DEST/Sources/HMUXMobileCore/"
cp "$ROOT/tests/fixtures/mobile-host-identity-cold-start/DisplayMetadataDependencies.swift" \
  "$DEST/Sources/HmuxSettings/"
cp "$ROOT/Packages/macOS/HmuxFoundation/Sources/HmuxFoundation/Concurrency/AtomicBooleanGate.swift" \
  "$DEST/Sources/HmuxFoundation/"
cp "$ROOT/Packages/macOS/HmuxFoundation/Sources/HmuxFoundationAtomicsC/HmuxFoundationAtomicsC.c" \
  "$DEST/Sources/HmuxFoundationAtomicsC/"
cp "$ROOT/Packages/macOS/HmuxFoundation/Sources/HmuxFoundationAtomicsC/include/HmuxFoundationAtomicsC.h" \
  "$DEST/Sources/HmuxFoundationAtomicsC/include/"
swift build --package-path "$DEST" -Xswiftc -warnings-as-errors
BIN_DIR=$(swift build --package-path "$DEST" --show-bin-path)
python3 "$ROOT/tests/test_mobile_host_identity_cold_start.py" \
  "$BIN_DIR/IdentityColdStartFixture" "$DEST/results.json"
