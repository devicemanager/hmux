// Copyright 2026 Manaflow, Inc.
// SPDX-License-Identifier: GPL-3.0-or-later

// Host-compilable tests for hmux-tui JSON-lines framing. No Chromium or gtest.

#include "chrome/browser/hmux_term/hmux_tui_protocol.h"

#include <cstdio>
#include <limits>
#include <string>
#include <vector>

namespace {

int checks = 0;
int failures = 0;

void Check(bool condition, const char* message) {
  ++checks;
  if (!condition) {
    ++failures;
    std::fprintf(stderr, "FAIL: %s\n", message);
  }
}

void CheckLines(const std::vector<std::string>& actual,
                const std::vector<std::string>& expected,
                const char* message) {
  Check(actual == expected, message);
}

}  // namespace

int main() {
  using hmux::HmuxTuiIdentityError;
  using hmux::HmuxTuiLineFramer;
  using hmux::HmuxTuiRegistryFenceDecision;

  {
    for (const std::string_view event : {
             "tree-changed", "workspace-added", "workspace-closed",
             "workspace-renamed", "workspace-moved", "screen-added",
             "screen-closed", "screen-renamed", "pane-added", "pane-closed",
             "tab-added", "tab-closed", "tab-renamed"}) {
      Check(hmux::IsHmuxTuiTreeEventName(event),
            "every supported tree delta invalidates the active path");
    }
    Check(!hmux::IsHmuxTuiTreeEventName("terminal-registry-changed"),
          "terminal registry events remain on their independent stream");
    Check(!hmux::IsHmuxTuiTreeEventName("title-changed"),
          "surface metadata does not force a tree snapshot");
  }

  {
    Check(hmux::SelectHmuxTuiSocketPath("/run/u/hmux.sock",
                                        "/tmp/hmux-tui-501/hmux.sock", 104) ==
              "/run/u/hmux.sock",
          "socket selector preserves a fitting runtime path");
    Check(hmux::SelectHmuxTuiSocketPath(std::string(103, 'p'),
                                        "/tmp/hmux-tui-501/hmux.sock", 104) ==
              std::string(103, 'p'),
          "socket selector reserves exactly one byte for the terminator");
    Check(hmux::SelectHmuxTuiSocketPath(std::string(104, 'p'),
                                        "/tmp/hmux-tui-501/hmux.sock", 104) ==
              "/tmp/hmux-tui-501/hmux.sock",
          "socket selector falls back at the native capacity boundary");
  }

  {
    Check(hmux::FenceHmuxTuiRegistrySnapshot(false, "", "", 0, "registry-a",
                                             "generation-a", 4) ==
              HmuxTuiRegistryFenceDecision::kAccept,
          "first terminal snapshot establishes the cursor");
    Check(hmux::FenceHmuxTuiRegistrySnapshot(
              true, "registry-a", "generation-a", 4, "registry-a",
              "generation-a", 5) == HmuxTuiRegistryFenceDecision::kAccept,
          "newer terminal snapshot in one epoch advances the cursor");
    Check(hmux::FenceHmuxTuiRegistrySnapshot(
              true, "registry-a", "generation-a", 5, "registry-a",
              "generation-a", 5) == HmuxTuiRegistryFenceDecision::kIgnore,
          "equal terminal snapshot is idempotent");
    Check(hmux::FenceHmuxTuiRegistrySnapshot(
              true, "registry-a", "generation-a", 5, "registry-a",
              "generation-a", 4) == HmuxTuiRegistryFenceDecision::kRefetch,
          "older same-epoch response cannot time-travel the GUI");
    Check(hmux::FenceHmuxTuiRegistrySnapshot(
              true, "registry-a", "generation-a", 9, "registry-a",
              "generation-b", 9) == HmuxTuiRegistryFenceDecision::kAccept,
          "new daemon generation is an authoritative epoch boundary");
    Check(hmux::FenceHmuxTuiRegistrySnapshot(
              true, "registry-a", "generation-a", 9, "registry-b",
              "generation-c", 0) == HmuxTuiRegistryFenceDecision::kAccept,
          "new durable registry replaces the old namespace");
    Check(hmux::FenceHmuxTuiRegistrySnapshot(true, "registry-a", "generation-a",
                                             9, "", "generation-c", 10) ==
              HmuxTuiRegistryFenceDecision::kInvalid,
          "snapshot without durable registry identity is invalid");
  }

  {
    Check(hmux::ValidateHmuxTuiTerminalEventRevisions(7, 7, {}),
          "empty event batch is valid only at the requested cursor");
    Check(hmux::ValidateHmuxTuiTerminalEventRevisions(7, 10, {8, 9, 10}),
          "contiguous event batch reaches its advertised barrier");
    Check(!hmux::ValidateHmuxTuiTerminalEventRevisions(7, 10, {8, 10}),
          "event gap fails closed to a snapshot");
    Check(!hmux::ValidateHmuxTuiTerminalEventRevisions(7, 9, {8, 9, 10}),
          "event beyond the advertised barrier is rejected");
    Check(!hmux::ValidateHmuxTuiTerminalEventRevisions(7, 6, {}),
          "event response cannot move its cursor backwards");
    Check(!hmux::ValidateHmuxTuiTerminalEventRevisions(
              std::numeric_limits<uint64_t>::max(),
              std::numeric_limits<uint64_t>::max(),
              {std::numeric_limits<uint64_t>::max()}),
          "event revision overflow is rejected");
  }

  {
    constexpr std::string_view kCommit =
        "0123456789abcdef0123456789abcdef01234567";
    constexpr std::string_view kGhosttyCommit =
        "89abcdef0123456789abcdef0123456789abcdef";
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kMinHmuxTuiProtocolVersion, 42, kCommit,
              "ffffffffffffffffffffffffffffffffffffffff", kGhosttyCommit,
              kGhosttyCommit) == HmuxTuiIdentityError::kBuildCommitMismatch,
          "a stale protocol-v7 build remains eligible for safe replacement");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kMinHmuxTuiProtocolVersion, 42, kCommit,
              kCommit, kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kInvalidEndpoint,
          "a legacy protocol cannot become ready with a matching stamp");
    Check(hmux::ValidateHmuxTuiIdentity("hmux-tui", 8, 42, kCommit, kCommit,
                                        kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kInvalidEndpoint,
          "an intermediate protocol cannot become ready");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 42, kCommit, kCommit,
                                        kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kNone,
          "exact stamped identity succeeds");
    Check(hmux::ValidateHmuxTuiIdentity(
              "not-hmux", hmux::kHmuxTuiProtocolVersion, 42, kCommit, kCommit,
                                        kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kInvalidEndpoint,
          "wrong application is rejected");
    Check(hmux::ValidateHmuxTuiIdentity("hmux-tui", 6, 42, kCommit, kCommit,
                                        kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kInvalidEndpoint,
          "older incompatible protocol is rejected");
    Check(hmux::ValidateHmuxTuiIdentity("hmux-tui", 10, 42, kCommit, kCommit,
                                        kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kInvalidEndpoint,
          "unknown future protocol is rejected");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 0, kCommit, kCommit,
                                        kGhosttyCommit, kGhosttyCommit) ==
              HmuxTuiIdentityError::kInvalidEndpoint,
          "zero server pid is rejected");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 42, std::nullopt,
              kCommit, kGhosttyCommit,
              kGhosttyCommit) == HmuxTuiIdentityError::kBuildCommitMissing,
          "unstamped production server is rejected");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 42,
              "ffffffffffffffffffffffffffffffffffffffff",
              kCommit, kGhosttyCommit,
              kGhosttyCommit) == HmuxTuiIdentityError::kBuildCommitMismatch,
          "different stamped build is rejected");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 42, kCommit, kCommit,
              std::nullopt, kGhosttyCommit) ==
              HmuxTuiIdentityError::kGhosttyCommitMissing,
          "server without a Ghostty stamp is rejected");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 42, kCommit, kCommit,
              "ffffffffffffffffffffffffffffffffffffffff",
              kGhosttyCommit) == HmuxTuiIdentityError::kGhosttyCommitMismatch,
          "server built from a different Ghostty commit is rejected");
    Check(hmux::ValidateHmuxTuiIdentity(
              "hmux-tui", hmux::kHmuxTuiProtocolVersion, 42, std::nullopt, "",
              std::nullopt, "") == HmuxTuiIdentityError::kNone,
          "source-tree development can omit a build pin");
    Check(!hmux::IsReplaceableHmuxTuiIdentityError(
              HmuxTuiIdentityError::kNone),
          "an exact server does not need replacement");
    Check(!hmux::IsReplaceableHmuxTuiIdentityError(
              HmuxTuiIdentityError::kInvalidEndpoint),
          "an arbitrary endpoint cannot trigger process replacement");
    Check(hmux::IsReplaceableHmuxTuiIdentityError(
              HmuxTuiIdentityError::kBuildCommitMissing) &&
              hmux::IsReplaceableHmuxTuiIdentityError(
                  HmuxTuiIdentityError::kBuildCommitMismatch) &&
              hmux::IsReplaceableHmuxTuiIdentityError(
                  HmuxTuiIdentityError::kGhosttyCommitMissing) &&
              hmux::IsReplaceableHmuxTuiIdentityError(
                  HmuxTuiIdentityError::kGhosttyCommitMismatch),
          "only stale or unstamped hmux-tui builds are replaceable");
    Check(!hmux::IsReplaceableHmuxTuiIdentityError(
              static_cast<HmuxTuiIdentityError>(255)),
          "an unclassified identity error fails closed");
  }

  {
    const std::string replay =
        "before\x1b]4;0;rgb:01/02/03\x1b\\middle"
        "\x1b]10;#abcdef\x07"
        "\x1b]4;15;#fefefe\x07"
        "after";
    const std::vector<uint8_t> filtered =
        hmux::StripHmuxTuiReplayPalette(replay);
    Check(std::string(filtered.begin(), filtered.end()) ==
              "beforemiddle\x1b]10;#abcdef\x07"
              "after",
          "state replay drops only terminated OSC 4 palette definitions");

    const std::string c1 = std::string("a") + static_cast<char>(0x9d) +
                           "4;1;#010203" + static_cast<char>(0x9c) + "b";
    const std::vector<uint8_t> c1_filtered =
        hmux::StripHmuxTuiReplayPalette(c1);
    Check(std::string(c1_filtered.begin(), c1_filtered.end()) == "ab",
          "state replay drops C1 OSC 4 palette definitions");

    const std::string unterminated = "keep\x1b]4;2;#112233";
    const std::vector<uint8_t> unchanged =
        hmux::StripHmuxTuiReplayPalette(unterminated);
    Check(std::string(unchanged.begin(), unchanged.end()) == unterminated,
          "unterminated OSC 4 is preserved");

    std::string full_palette = "prefix";
    for (int index = 0; index < 256; ++index) {
      full_palette.append("\x1b]4;");
      full_palette.append(std::to_string(index));
      full_palette.append(";#010203\x1b\\");
    }
    full_palette.append("\x1b]10;#abcdef\x1b\\suffix");
    const std::vector<uint8_t> full_filtered =
        hmux::StripHmuxTuiReplayPalette(full_palette);
    Check(std::string(full_filtered.begin(), full_filtered.end()) ==
              "prefix\x1b]10;#abcdef\x1b\\suffix",
          "all 256 replay palette slots are removed without touching OSC 10");
  }

  {
    hmux::HmuxTuiInputQueue input(5);
    Check(input.Push(std::string_view("a\0b", 3)),
          "binary input is queued within the cap");
    Check(input.pending_bytes() == 3, "pending input counts embedded NUL");
    Check(input.BeginWrite() == std::vector<uint8_t>({'a', 0, 'b'}),
          "first input batch preserves exact bytes");
    Check(input.write_in_flight(), "input batch becomes in flight");
    Check(input.Push("cd"), "input coalesces behind an in-flight batch");
    Check(!input.Push("efgh"), "pending input cap rejects the whole new chunk");
    Check(input.BeginWrite().empty(),
          "second input write waits for completion");
    input.FinishWrite();
    Check(input.BeginWrite() == std::vector<uint8_t>({'c', 'd'}),
          "coalesced input starts after completion");
    input.CancelWrite();
    Check(!input.write_in_flight(), "cancel releases input backpressure");
    Check(input.Push("xy"), "queue accepts input after cancellation");
    input.Clear();
    Check(input.pending_bytes() == 0 && !input.write_in_flight(),
          "clear drops pending input and in-flight state");
  }

  {
    hmux::HmuxTuiResizeCoalescer resizes;
    Check(!resizes.BeginWrite({80, 24}),
          "default desired grid does not emit a redundant resize");
    resizes.SetDesired(0, 0);
    Check(resizes.desired() == hmux::HmuxTuiGridSize{1, 1},
          "desired resize clamps to a valid grid");
    const std::optional<hmux::HmuxTuiGridSize> first =
        resizes.BeginWrite({80, 24});
    Check(first && *first == hmux::HmuxTuiGridSize{1, 1},
          "first changed grid starts a resize");
    resizes.SetDesired(120, 41);
    Check(!resizes.BeginWrite({1, 1}),
          "new resize is held while one is in flight");
    resizes.FinishWrite();
    const std::optional<hmux::HmuxTuiGridSize> latest =
        resizes.BeginWrite({1, 1});
    Check(latest && *latest == hmux::HmuxTuiGridSize{120, 41},
          "resize completion releases only the latest desired grid");
    resizes.CancelWrite();
    Check(!resizes.write_in_flight(), "resize cancellation releases the gate");
  }

  {
    HmuxTuiLineFramer framer;
    std::vector<std::string> lines;
    Check(framer.Push("{\"id\":1", &lines) == HmuxTuiLineFramer::Result::kOk,
          "partial first read succeeds");
    Check(lines.empty(), "partial line is buffered");
    Check(framer.buffered_bytes() == 7, "partial byte count is exact");
    Check(framer.Push(",\"ok\":true}\n", &lines) ==
              HmuxTuiLineFramer::Result::kOk,
          "partial second read succeeds");
    CheckLines(lines, {"{\"id\":1,\"ok\":true}"},
               "partial reads join into one frame");
    Check(framer.buffered_bytes() == 0, "complete frame drains buffer");
  }

  {
    HmuxTuiLineFramer framer;
    std::vector<std::string> lines;
    Check(framer.Push("\n{\"event\":\"output\"}\r\n\n{\"id\":2}\ntrail",
                      &lines) == HmuxTuiLineFramer::Result::kOk,
          "mixed frames succeed");
    CheckLines(lines, {"{\"event\":\"output\"}", "{\"id\":2}"},
               "blank lines are ignored and CRLF is stripped");
    Check(framer.buffered_bytes() == 5, "trailing partial line remains");
    lines.clear();
    Check(framer.Push("ing\n", &lines) == HmuxTuiLineFramer::Result::kOk,
          "trailing frame completes");
    CheckLines(lines, {"trailing"}, "trailing pieces preserve order");
  }

  {
    HmuxTuiLineFramer framer(8);
    std::vector<std::string> lines;
    Check(framer.Push("12345678\n", &lines) == HmuxTuiLineFramer::Result::kOk,
          "line exactly at cap succeeds");
    CheckLines(lines, {"12345678"}, "capped line is emitted");
    lines.clear();
    Check(framer.Push("12345", &lines) == HmuxTuiLineFramer::Result::kOk,
          "oversize prefix buffers");
    Check(
        framer.Push("6789", &lines) == HmuxTuiLineFramer::Result::kLineTooLarge,
        "oversize frame is rejected across reads");
    Check(framer.buffered_bytes() == 0, "overflow clears buffered tail");
    Check(framer.Push("ok\n", &lines) == HmuxTuiLineFramer::Result::kOk,
          "framer can restart after overflow");
    CheckLines(lines, {"ok"}, "restart does not retain oversized bytes");
  }

  std::printf("hmux-tui-protocol: %d checks, %d failures\n", checks, failures);
  return failures == 0 ? 0 : 1;
}
