import { describe, expect, test } from "bun:test";
import {
  HMUX_TUI_PORT,
  hmuxTuiDaemonCommand,
  hmuxTuiInstallCommand,
  hmuxTuiPinCheckCommand,
} from "../services/vms/drivers/hmuxTuiDaemon";

const SOURCE = {
  url: "https://files.cmux.com/cmux-tui/test/cmux-tui-x86_64-unknown-linux-musl",
  sha256: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  commit: "0123456789abcdef0123456789abcdef01234567",
  builtAt: null, hookUrl: "https://files.cmux.com/cmux-tui/test/cmux-tui-hook-x86_64-unknown-linux-musl", hookSha256: "1".repeat(64),
} as const;

describe("Freestyle Cloud VM daemon repair", () => {
  test("install and start use the pinned managed daemon", () => {
    const install = hmuxTuiInstallCommand(SOURCE);
    // The binary follows the daemon's layout, so a work-user machine gets one
    // its non-root sessions can execute (/root is 0700).
    expect(install).toContain('HMUX_TUI_BIN="$HMUX_TUI_HOME/.hmux/bin/hmux-tui"');
    expect(install).toContain(SOURCE.sha256);
    expect(install).toContain(SOURCE.url);
    expect(install).toContain("sha256sum -c");
    expect(install).not.toContain("hmuxd-remote");

    const daemon = hmuxTuiDaemonCommand(`[::]:${HMUX_TUI_PORT}`);
    expect(daemon).toContain("server start --session cloud");
    expect(daemon).toContain(`--remote-ws [::]:${HMUX_TUI_PORT}`);
    // The cloud listener is reachable only inside the owner's private network.
    expect(daemon).toContain("--remote-ws-trusted-carrier");
    expect(daemon).toContain('"$HMUX_TUI_BIN" server start');
    expect(daemon).not.toContain("hmuxd-remote");
  });

  test("pin check verifies the managed binary digest", () => {
    const pinCheck = hmuxTuiPinCheckCommand(SOURCE);
    expect(pinCheck).toContain(SOURCE.sha256);
    expect(pinCheck).toContain("sha256sum -c");
  });
});
