#!/bin/bash
# Run only on a disposable/leased Mac or hosted CI, never the user's shared Mac.
# This compiles the persistent command transport and tests with app-level value dependencies stubbed.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:?pass an isolated scratch directory}
mkdir -p "$DEST/Sources/CloudCommandFixture" "$DEST/Tests/CloudCommandFixtureTests"
# HmuxTerminalSizing has no dependencies, so the fixture links the real package
# instead of stubbing the shared sizing value types.
SIZING_PACKAGE="$ROOT/Packages/Shared/HmuxTerminalSizing"
cat > "$DEST/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription
let sizing = Target.Dependency.product(name: "HmuxTerminalSizing", package: "HmuxTerminalSizing")
let package = Package(
    name: "CloudCommandFixture",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "$SIZING_PACKAGE")],
    targets: [
        .target(name: "CloudCommandFixture", dependencies: [sizing]),
        .testTarget(name: "CloudCommandFixtureTests", dependencies: ["CloudCommandFixture", sizing])
    ],
    swiftLanguageModes: [.v5]
)
SWIFT
# CloudTuiTerminalProjectionTarget lives in the HmuxSurfaceCatalogModel package, not in HmuxCloud.
cp "$ROOT/Packages/macOS/HmuxSurfaceCatalogModel/Sources/HmuxSurfaceCatalogModel/CloudTuiTerminalProjectionTarget.swift" \
    "$DEST/Sources/CloudCommandFixture/"
cp "$ROOT/Packages/macOS/HmuxCloud/Sources/HmuxCloud/Link/CloudTuiPersistentResourceConnection.swift" "$DEST/Sources/CloudCommandFixture/"
# The rest of the transport lives in the HmuxCloudTui package.
for name in CloudTuiPersistentRequestBuilder \
    CloudTuiManualIOConnection CloudTuiManualIODescriptorLease CloudTuiManualIOCommand \
    CloudTuiManualIOFrame CloudTuiManualIOFrameDecoder CloudTuiRemoteColors; do
    cp "$ROOT/Packages/macOS/HmuxCloudTui/Sources/HmuxCloudTui/$name.swift" "$DEST/Sources/CloudCommandFixture/"
done
cp "$ROOT/tests/fixtures/cloud-command-deadlines/StandaloneDependencies.swift" "$DEST/Sources/CloudCommandFixture/"
# The fixture stubs the catalog value types it needs (StandaloneDependencies.swift) and
# compiles the transport into one module, so the copied sources and tests must not import
# the real packages.
sed -i.bak -e '/^import HmuxSurfaceCatalogModel$/d' -e '/^import HmuxCloudTui$/d' \
    "$DEST/Sources/CloudCommandFixture/"*.swift
rm -f "$DEST/Sources/CloudCommandFixture/"*.bak
for name in CloudCommandDeadlineClock CloudCommandDeadlineTests CloudTuiManualIOConnectionTests; do
    cp "$ROOT/hmuxTests/$name.swift" "$DEST/Tests/CloudCommandFixtureTests/"
done
sed -i.bak -e '/^import HmuxCloudTui$/d' -e '/^import HmuxCloud$/d' "$DEST/Tests/CloudCommandFixtureTests/"*.swift
rm -f "$DEST/Tests/CloudCommandFixtureTests/"*.bak
swift test --package-path "$DEST" -Xswiftc -warnings-as-errors
