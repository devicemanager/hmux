"use strict";

const IMMUTABLE_RELEASE_ASSETS = [
  "hmux-macos.dmg",
  "hmux-macos-arm64.dmg",
  "hmux-macos-x86_64.dmg",
  "appcast.xml",
  "appcast-arm64.xml",
  "appcast-x86_64.xml",
  "hmuxd-remote-darwin-arm64",
  "hmuxd-remote-darwin-amd64",
  "hmuxd-remote-linux-arm64",
  "hmuxd-remote-linux-amd64",
  "hmuxd-remote-checksums.txt",
  "hmuxd-remote-manifest.json",
];
const RELEASE_ASSET_GUARD_STATE = Object.freeze({
  CLEAR: "clear",
  PARTIAL: "partial",
  COMPLETE: "complete",
});

function evaluateReleaseAssetGuard({ existingAssetNames, immutableAssetNames = IMMUTABLE_RELEASE_ASSETS }) {
  const immutableAssets = immutableAssetNames || IMMUTABLE_RELEASE_ASSETS;
  const existing = new Set(existingAssetNames || []);
  const conflicts = immutableAssets.filter((assetName) => existing.has(assetName));
  const missingImmutableAssets = immutableAssets.filter((assetName) => !existing.has(assetName));

  let guardState = RELEASE_ASSET_GUARD_STATE.CLEAR;
  if (conflicts.length === immutableAssets.length && immutableAssets.length > 0) {
    guardState = RELEASE_ASSET_GUARD_STATE.COMPLETE;
  } else if (conflicts.length > 0) {
    guardState = RELEASE_ASSET_GUARD_STATE.PARTIAL;
  }

  return {
    conflicts,
    missingImmutableAssets,
    guardState,
    hasPartialConflict: guardState === RELEASE_ASSET_GUARD_STATE.PARTIAL,
    shouldSkipBuildAndUpload: guardState === RELEASE_ASSET_GUARD_STATE.COMPLETE,
    shouldSkipUpload: guardState === RELEASE_ASSET_GUARD_STATE.COMPLETE,
  };
}

module.exports = {
  IMMUTABLE_RELEASE_ASSETS,
  RELEASE_ASSET_GUARD_STATE,
  evaluateReleaseAssetGuard,
};
