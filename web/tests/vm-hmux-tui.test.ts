import { spawn } from "node:child_process";
import { runChild } from "./helpers/run-child";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "bun:test";
import {
  HMUX_TUI_DAEMON_TERMINAL_ENV,
  HMUX_TUI_LAYOUT_MARKER_PATH,
  hmuxTuiDaemonCommand,
  hmuxTuiAsDaemonUser,
  hmuxTuiHooksReadyCommand,
  hmuxTuiInstallCommand,
  hmuxTuiPinnedManifestUrl,
  hmuxTuiLayoutSelector,
  hmuxTuiPinCheckCommand,
  hmuxTuiManifestUrl,
  hmuxTuiRunCommand,
  parseHmuxTuiManifest,
  hmuxTuiAttachBundleCommand,
  hmuxTuiTrustedListenerProbe,
  parseHmuxTuiAttachBundle,
} from "../services/vms/drivers/hmuxTuiDaemon";

const SHA = "c7a3155341a85a2f10a873d69a041bdf1855ec059a802e58e0779a7a6bdec607";
const COMMIT = "5a4780614cecd8e8ef040a24478f928ef31cc4ae";
const MANIFEST = `https://files.cmux.com/cmux-tui/${COMMIT}/manifest.json`;
const URL = `https://files.cmux.com/cmux-tui/${COMMIT}/hmux-tui-x86_64-unknown-linux-musl`;
const HOOK_SHA = "9f2e4c1a7b3d5e6f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5a6b7";
const HOOK_URL = `https://files.cmux.com/cmux-tui/${COMMIT}/hmux-tui-hook-x86_64-unknown-linux-musl`;

function withEnv(values: Record<string, string | undefined>, run: () => void) {
  const previous: Record<string, string | undefined> = {};
  for (const [key, value] of Object.entries(values)) {
    previous[key] = process.env[key];
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    run();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

describe("hmux-tui daemon source", () => {
  test("follows the rolling latest manifest unless a deployment pins one", () => {
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: undefined }, () =>
      expect(hmuxTuiManifestUrl()).toBe("https://files.cmux.com/cmux-tui/latest/manifest.json"));
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: MANIFEST }, () => expect(hmuxTuiManifestUrl()).toBe(MANIFEST));
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: "http://files.cmux.com/x/manifest.json" }, () =>
      expect(() => hmuxTuiManifestUrl()).toThrow(/https/));
  });

  test("takes the linux musl build and its sha256 from the manifest", () => {
    const source = parseHmuxTuiManifest(MANIFEST, {
      commit: COMMIT,
      builtAt: "2026-08-19T07:05:35Z",
      binaries: {
        "hmux-tui-aarch64-apple-darwin": "a".repeat(64),
        "hmux-tui-x86_64-unknown-linux-musl": SHA.toUpperCase(),
        "hmux-tui-hook-x86_64-unknown-linux-musl": HOOK_SHA.toUpperCase(),
      },
    });
    // The hook helper comes from the same commit as the daemon: a machine
    // never pairs a daemon with a helper of another generation.
    expect(source).toEqual({ url: URL, sha256: SHA, commit: COMMIT, builtAt: "2026-08-19T07:05:35Z", hookUrl: HOOK_URL, hookSha256: HOOK_SHA });
  });

  test("pins binaries from the manifest commit when the manifest uses latest", () => {
    const source = parseHmuxTuiManifest("https://files.cmux.com/cmux-tui/latest/manifest.json", {
      commit: COMMIT,
      binaries: {
        "hmux-tui-x86_64-unknown-linux-musl": SHA,
        "hmux-tui-hook-x86_64-unknown-linux-musl": HOOK_SHA,
      },
    });
    expect(source.url).toBe(URL);
    expect(source.hookUrl).toBe(HOOK_URL);
  });

  test("fails closed on a manifest without a commit, without the musl build, or without the hook helper", () => {
    const both = { "hmux-tui-x86_64-unknown-linux-musl": SHA, "hmux-tui-hook-x86_64-unknown-linux-musl": HOOK_SHA };
    expect(() => parseHmuxTuiManifest(MANIFEST, { binaries: both })).toThrow(/commit/);
    expect(() => parseHmuxTuiManifest(MANIFEST, { commit: COMMIT, binaries: { "hmux-tui-x86_64-unknown-linux-gnu": SHA, "hmux-tui-hook-x86_64-unknown-linux-musl": HOOK_SHA } })).toThrow(/musl/);
    expect(() => parseHmuxTuiManifest(MANIFEST, { commit: COMMIT, binaries: { "hmux-tui-x86_64-unknown-linux-musl": SHA } })).toThrow(/vm_artifact_unavailable/);
    expect(() => parseHmuxTuiManifest(MANIFEST, "nonsense")).toThrow();
  });

  test("a pinned manifest is the commit's sibling of the rolling pointer", () => {
    expect(hmuxTuiPinnedManifestUrl(COMMIT)).toBe(MANIFEST);
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: "https://files.example/tui/deadbeef/manifest.json" }, () =>
      expect(hmuxTuiPinnedManifestUrl(COMMIT)).toBe(`https://files.example/tui/${COMMIT}/manifest.json`));
    expect(() => hmuxTuiPinnedManifestUrl("abc")).toThrow(/full sha/);
  });
});

describe("hmux-tui install and daemon commands", () => {
  test("installs into the daemon's own home, verifies the pin before and after download, and probes the binary", () => {
    const command = hmuxTuiInstallCommand({ url: URL, sha256: SHA, commit: COMMIT, builtAt: null, hookUrl: "https://files.cmux.com/cmux-tui/test/cmux-tui-hook-x86_64-unknown-linux-musl", hookSha256: "1".repeat(64) });
    // One runtime selection, shared with the daemon launch, so install and
    // launch can never disagree about where the binary lives.
    expect(command).toContain(hmuxTuiLayoutSelector());
    expect(command).toContain('mkdir -p "$(dirname "$HMUX_TUI_BIN")"');
    // Skip the download when the installed copy already matches the pin.
    expect(command).toContain(`'${SHA}' "$HMUX_TUI_BIN" | sha256sum -c >/dev/null 2>&1; then :; else`);
    // The download is verified against the same pin before it replaces anything.
    expect(command).toContain(`curl -fsSL --retry 3 -o "$HMUX_TUI_TMP" '${URL}'`);
    expect(command).toContain(`wget -q -O "$HMUX_TUI_TMP" '${URL}'`);
    expect(command).toContain(`'${SHA}' "$HMUX_TUI_TMP" | sha256sum -c >/dev/null 2>&1 && chmod 755`);
    expect(command).toContain('ln -sfn "$HMUX_TUI_BIN" /usr/local/bin/hmux-tui');
    // Only the nodes the install created; never a walk of the state tree.
    expect(command).toContain('chown "$HMUX_TUI_USER:$HMUX_TUI_USER" "$HMUX_TUI_HOME/.hmux" "$HMUX_TUI_HOME/.hmux/bin" "$HMUX_TUI_BIN"');
    expect(command).not.toContain("chown -R");
    expect(command).toContain('"$HMUX_TUI_BIN" --version');
  });

  test("installs the hook helper beside the daemon from the same pin and writes the Claude Code and Codex hooks as the daemon user", () => {
    const source = { url: URL, sha256: SHA, commit: COMMIT, builtAt: null, hookUrl: HOOK_URL, hookSha256: HOOK_SHA };
    const command = hmuxTuiInstallCommand(source);
    // Beside the binary: the one place `agent hook install` finds it without a PATH search.
    expect(command).toContain('HMUX_TUI_HOOK_BIN="$(dirname "$HMUX_TUI_BIN")/hmux-tui-hook"');
    expect(command).toContain(`'${HOOK_SHA}' "$HMUX_TUI_HOOK_BIN" | sha256sum -c >/dev/null 2>&1; then :; else`);
    expect(command).toContain(`curl -fsSL --retry 3 -o "$HMUX_TUI_HOOK_TMP" '${HOOK_URL}'`);
    expect(command).toContain(`'${HOOK_SHA}' "$HMUX_TUI_HOOK_TMP" | sha256sum -c >/dev/null 2>&1 && chmod 755`);
    expect(command).toContain('"$HMUX_TUI_BIN" "$HMUX_TUI_HOOK_BIN" 2>/dev/null || true');
    // The hooks are the daemon user's (HOME=/home/hmux), never root's: root's
    // settings are invisible to the terminals the daemon spawns.
    const install = hmuxTuiAsDaemonUser('"$HMUX_TUI_BIN" agent hook install claude codex >/dev/null');
    expect(command).toContain(install);
    expect(command.indexOf('"$HMUX_TUI_BIN" --version')).toBeLessThan(command.indexOf(install));
    // And proven, not assumed: helper installed and byte-equal to the pin,
    // every provider config carrying the hmux marker, codex trust state written.
    expect(command).toContain('test -x "$HMUX_TUI_HOME/.local/share/hmux-tui/bin/hmux-tui-hook"');
    expect(command).toContain('cmp -s "$HMUX_TUI_HOOK_BIN" "$HMUX_TUI_HOME/.local/share/hmux-tui/bin/hmux-tui-hook"');
    // Structured status, not a text grep: a user-edited entry reports partial and is repaired.
    expect(command).toContain(hmuxTuiAsDaemonUser('"$HMUX_TUI_BIN" --json agent hook status claude codex'));
    expect(command).toContain('all(s.get(i) == "installed" for i in ["claude","codex"])');
    expect(command).not.toContain("grep -q hmux-tui-journal-hook");
  });

  test("the pinned manifest URL keeps the mirror's origin and query and handles a root-level pointer", () => {
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: "https://mirror.example/manifest.json?token=abc" }, () =>
      expect(hmuxTuiPinnedManifestUrl(COMMIT)).toBe(`https://mirror.example/${COMMIT}/manifest.json?token=abc`));
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: "https://files.example/tui/latest/manifest.json?x=1" }, () =>
      expect(hmuxTuiPinnedManifestUrl(COMMIT)).toBe(`https://files.example/tui/${COMMIT}/manifest.json?x=1`));
    withEnv({ HMUX_VM_HMUX_TUI_MANIFEST_URL: "https://files.example/tui/latest/index.json" }, () =>
      expect(() => hmuxTuiPinnedManifestUrl(COMMIT)).toThrow(/manifest\.json/));
  });

  test("the hooks-ready check runs as the daemon layout and checks the installed helper", () => {
    expect(hmuxTuiHooksReadyCommand()).toContain(hmuxTuiLayoutSelector());
    expect(hmuxTuiHooksReadyCommand()).toContain('test -x "$HMUX_TUI_HOME/.local/share/hmux-tui/bin/hmux-tui-hook"');
  });

  // Regression: `sha256sum -c -s` is BusyBox-only. GNU coreutils (the xfce-vnc desktop
  // image) rejects `-s` ("invalid option -- 's'"), which failed every create with a 502.
  test("the pin check never uses the BusyBox-only sha256sum -s flag", () => {
    const command = hmuxTuiInstallCommand({ url: URL, sha256: SHA, commit: COMMIT, builtAt: null, hookUrl: "https://files.cmux.com/cmux-tui/test/cmux-tui-hook-x86_64-unknown-linux-musl", hookSha256: "1".repeat(64) });
    expect(command).not.toMatch(/sha256sum[^|&;]*\s-s\b/);
    expect(command).not.toContain("--status");
    expect(command).toContain("sha256sum -c >/dev/null 2>&1");
  });

  test("the pin check reads the same binary the daemon runs", () => {
    const command = hmuxTuiPinCheckCommand({ url: URL, sha256: SHA, commit: COMMIT, builtAt: null, hookUrl: "https://files.cmux.com/cmux-tui/test/cmux-tui-hook-x86_64-unknown-linux-musl", hookSha256: "1".repeat(64) });
    expect(command).toContain(hmuxTuiLayoutSelector());
    expect(command).toContain('test -x "$HMUX_TUI_BIN"');
    expect(command).toContain(`'${SHA}' "$HMUX_TUI_BIN" | sha256sum -c`);
  });

  test("the daemon drops to the work user and serves /v1/link on its own port", () => {
    const command = hmuxTuiDaemonCommand();
    // Terminals must be non-root shells: agents refuse root
    // (`claude --dangerously-skip-permissions`), sudo is the escalation path.
    expect(command).toContain(hmuxTuiLayoutSelector());
    // setpriv, not runuser or su: it EXECs in place, so the daemon is the
    // direct child of its supervisor. With a wrapper in between, SIGTERM never
    // reached the daemon (it was SIGKILLed, and its next start rejected the
    // half-written shutdown record), and `pgrep -f` matched the wrapper first.
    expect(command).toContain(
      `exec setpriv --reuid="$HMUX_TUI_USER" --regid="$HMUX_TUI_USER" --init-groups env HOME="$HMUX_TUI_HOME" USER="$HMUX_TUI_USER" LOGNAME="$HMUX_TUI_USER" SHELL=/bin/bash ${HMUX_TUI_DAEMON_TERMINAL_ENV} "$HMUX_TUI_BIN"`,
    );
    expect(command).not.toContain("runuser");
    expect(command).toContain('cd "$HMUX_TUI_HOME"');
    expect(command).toContain(`printf '%s\\n' "$HMUX_TUI_LAYOUT" > ${HMUX_TUI_LAYOUT_MARKER_PATH}`);
    expect(command).toContain("server start --session cloud --remote-ws 0.0.0.0:1337 --remote-ws-insecure-bind --remote-ws-trusted-carrier");
  });

  test("driver-side hmux-tui calls read the daemon's own state, not root's", () => {
    const command = hmuxTuiRunCommand("server status --session cloud");
    expect(command).toContain(hmuxTuiLayoutSelector());
    expect(command).toContain('setpriv --reuid="$HMUX_TUI_USER" --regid="$HMUX_TUI_USER" --init-groups env HOME="$HMUX_TUI_HOME"');
    expect(command).toContain('"$HMUX_TUI_BIN" server status --session cloud');
  });

  test("the work user is used only when it can do the job it promises", () => {
    const selector = hmuxTuiLayoutSelector();
    expect(selector).toContain("id -u hmux");
    expect(selector).toContain("command -v setpriv");
    expect(selector).toContain("setpriv --reuid=hmux --regid=hmux --init-groups test -w /home/hmux");
    // Passwordless sudo is part of the promise: a session that cannot escalate
    // is worse than a root session, so a broken sudoers picks the root layout.
    expect(selector).toContain("setpriv --reuid=hmux --regid=hmux --init-groups sudo -n true");
    // No PAM session per probe: the supervisor evaluates this on every restart.
    expect(selector).not.toContain("runuser");
    expect(selector).toContain("HMUX_TUI_USER=root; HMUX_TUI_HOME=/root; HMUX_TUI_LAYOUT=root");
  });

  /** Runs a shell snippet with `bin` first on PATH and returns its stdout. */
  async function runWithStubs(snippet: string, stubs: Record<string, string>): Promise<string> {
    const root = mkdtempSync(join(tmpdir(), "hmux-tui-layout-"));
    const fakeBin = join(root, "bin");
    mkdirSync(fakeBin, { recursive: true });
    try {
      for (const [name, body] of Object.entries(stubs)) {
        const file = join(fakeBin, name);
        writeFileSync(file, body);
        chmodSync(file, 0o755);
      }
      const result = await runChild("/bin/sh", ["-c", snippet], {
        env: { ...process.env, PATH: [fakeBin, "/usr/bin", "/bin"].join(":") },
      });
      expect(result.status).toBe(0);
      return (result.stdout ?? "").trim();
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }

  const report = '; printf %s:%s:%s "$HMUX_TUI_USER" "$HMUX_TUI_HOME" "$HMUX_TUI_BIN"';

  test("a machine with a usable work user runs its sessions as that user", async () => {
    const out = await runWithStubs(`${hmuxTuiLayoutSelector()}${report}`, {
      id: "#!/bin/sh\nexit 0\n",
      setpriv: "#!/bin/sh\nexit 0\n",
      sudo: "#!/bin/sh\nexit 0\n",
    });
    expect(out).toBe("hmux:/home/hmux:/home/hmux/.hmux/bin/hmux-tui");
  });

  test("a machine from a pre-work-user image keeps its root daemon and /root state", async () => {
    const out = await runWithStubs(`${hmuxTuiLayoutSelector()}${report}`, {
      // No such user: an image baked before the work user existed.
      id: "#!/bin/sh\nexit 1\n",
      setpriv: "#!/bin/sh\nexit 0\n",
    });
    expect(out).toBe("root:/root:/root/.hmux/bin/hmux-tui");
  });

  test("a work user without passwordless sudo falls back to root rather than trapping the session", async () => {
    const out = await runWithStubs(`${hmuxTuiLayoutSelector()}${report}`, {
      id: "#!/bin/sh\nexit 0\n",
      // the writability probe passes, the `sudo -n true` probe does not.
      setpriv: '#!/bin/sh\ncase "$*" in *sudo*) exit 1;; esac\nexit 0\n',
      sudo: "#!/bin/sh\nexit 0\n",
    });
    expect(out).toBe("root:/root:/root/.hmux/bin/hmux-tui");
  });
});

describe("hmux-tui attach bundle", () => {
  const stdoutFor = (probe: string, devices: string, trusted: string) =>
    ["__HMUX_PROBE__", probe, "__HMUX_DEVICES__", devices, "__HMUX_TRUSTED__", trusted, "__HMUX_END__", ""].join("\n");

  /** Runs the attach bundle against a fake hmux-tui and returns its result and recorded calls. */
  const runBundle = async (readyGate: string, deviceFingerprint?: string) => {
    const root = mkdtempSync(join(tmpdir(), "hmux-tui-attach-bundle-"));
    const binary = join(root, "hmux-tui");
    const callsPath = join(root, "calls");
    // The bundle reads the daemon's state, so it runs every call as the
    // daemon's user. This host has no setpriv (and no such user); the stub
    // makes the drop-to-user a pass-through so the rest of the bundle is
    // exercised as written.
    const fakeBin = join(root, "bin");
    mkdirSync(fakeBin, { recursive: true });
    const setpriv = join(fakeBin, "setpriv");
    writeFileSync(setpriv, ["#!/bin/sh", "while [ $# -gt 0 ]; do case \"$1\" in --*) shift;; *) break;; esac; done", 'exec "$@"', ""].join("\n"));
    chmodSync(setpriv, 0o755);
    writeFileSync(binary, [
      "#!/bin/sh",
      "printf '%s\\n' \"$*\" >> \"$HMUX_TEST_CALLS\"",
      "case \"$*\" in",
      `  'remote-probe --json') printf '%s\\n' '{"build_identity":"abc123","remote_protocol":12,"version":"0.13.0"}' ;;`,
      `  'remote enroll devices --session cloud --json') printf '%s\\n' '[{"fingerprint":"fp-1","revoked_at_unix":null}]' ;;`,
      "  *) exit 64 ;;",
      "esac",
      "",
    ].join("\n"));
    chmodSync(binary, 0o755);
    try {
      const result = await runChild("/bin/sh", ["-c", hmuxTuiAttachBundleCommand({ readyGate, deviceFingerprint, binary })], {
        env: {
          ...process.env,
          HMUX_TEST_CALLS: callsPath,
          PATH: [fakeBin, process.env.PATH || ""].join(":"),
        },
        timeout: 5_000,
      });
      expect(result.error).toBeUndefined();
      return {
        status: result.status,
        stdout: result.stdout,
        calls: existsSync(callsPath) ? readFileSync(callsPath, "utf8").trim().split("\n") : [],
      };
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  };

  test("a successful readiness exit reads build, devices, and the trusted probe; nothing is minted", async () => {
    const result = await runBundle("exit 0", "fp-new");
    expect(result.status).toBe(0);
    expect(result.calls).toEqual([
      "remote-probe --json",
      "remote enroll devices --session cloud --json",
    ]);
    expect(hmuxTuiAttachBundleCommand({})).not.toContain("remote enroll create");
    const bundle = parseHmuxTuiAttachBundle(result.stdout, "freestyle", "vm-1", "fp-new");
    expect(bundle.daemonBuild).toEqual({ commit: "abc123", remoteProtocol: 12, version: "0.13.0" });
    expect(bundle.enrolled).toBe(false);
    // No cloud daemon runs on the test host, so the probe reports untrusted.
    expect(bundle.trustedCarrier).toBe(false);
  });

  test("a failed readiness exit returns the repair signal without calling the daemon", async () => {
    const result = await runBundle("exit 1");
    expect(result.status).toBe(3);
    expect(result.calls).toEqual([]);
    expect(result.stdout).toBe("");
  });

  test("an enrolled device is recognized so the heal never restarts under it", async () => {
    const result = await runBundle("exit 0", "fp-1");
    expect(result.status).toBe(0);
    const bundle = parseHmuxTuiAttachBundle(result.stdout, "freestyle", "vm-1", "fp-1");
    expect(bundle.enrolled).toBe(true);
  });

  test("rejects a malformed device fingerprint", () => {
    expect(() => hmuxTuiAttachBundleCommand({ deviceFingerprint: "bad fp; rm -rf /" })).toThrow("unexpected shape");
  });

  test("the trusted probe requires the env or flag on the live daemon and a binary that knows the flag", () => {
    const probe = hmuxTuiTrustedListenerProbe();
    expect(probe).toContain("pgrep -f 'hmux-tui server [s]tart'");
    expect(probe).toContain("/proc/$p/environ");
    expect(probe).toContain("'HMUX_TUI_REMOTE_WS_TRUSTED_CARRIER=1'");
    expect(probe).toContain("/proc/$p/cmdline");
    expect(probe).toContain("'--remote-ws-trusted-carrier'");
    // The running binary answers for itself, so a stale install never reads as
    // trusted: an old parser rejects the flag before it reaches --version.
    expect(probe).toContain("\"/proc/$p/exe\" --remote-ws-trusted-carrier --version >/dev/null 2>&1");
    expect(probe).not.toContain("sha256sum");
  });

  test("parses build, enrollment, and the trusted flag from the fenced output; a missing flag is untrusted", () => {
    const parsed = parseHmuxTuiAttachBundle(
      stdoutFor(
        JSON.stringify({ build_identity: "abc123", remote_protocol: 12, version: "0.13.0" }),
        JSON.stringify([{ fingerprint: "fp-2", revoked_at_unix: null }]),
        "1",
      ),
      "freestyle",
      "vm-1",
      "fp-1",
    );
    expect(parsed.daemonBuild).toEqual({ commit: "abc123", remoteProtocol: 12, version: "0.13.0" });
    expect(parsed.enrolled).toBe(false);
    expect(parsed.trustedCarrier).toBe(true);
    expect(parseHmuxTuiAttachBundle(stdoutFor("{}", "[]", "0"), "freestyle", "vm-1").trustedCarrier).toBe(false);
    expect(parseHmuxTuiAttachBundle(stdoutFor("{}", "[]", ""), "freestyle", "vm-1").trustedCarrier).toBe(false);
    expect(parseHmuxTuiAttachBundle("garbage", "freestyle", "vm-1").trustedCarrier).toBe(false);
  });

  test("an enrolled, unrevoked fingerprint counts; a revoked one does not", () => {
    const enrolled = parseHmuxTuiAttachBundle(
      stdoutFor("{}", JSON.stringify([{ fingerprint: "fp-1", revoked_at_unix: null }]), "1"),
      "freestyle", "vm-1", "fp-1",
    );
    expect(enrolled.enrolled).toBe(true);
    expect(enrolled.daemonBuild).toBeNull();
    const revoked = parseHmuxTuiAttachBundle(
      stdoutFor("{}", JSON.stringify([{ fingerprint: "fp-1", revoked_at_unix: 1 }]), "1"),
      "freestyle", "vm-1", "fp-1",
    );
    expect(revoked.enrolled).toBe(false);
  });
});
