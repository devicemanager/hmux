#!/usr/bin/env bun
/**
 * Disposable compatibility probe for a minimal Freestyle image.
 *
 * This is intentionally not a promotion path. A BusyBox VM is useful only if
 * the hmux-tui daemon survives without the Ubuntu devbox contract. The probe
 * boots `freestyle/busybox`, installs the pinned static hmux-tui binary, starts
 * it, downloads the optional fx binary, and samples RSS. It deletes the VM in
 * a finally block and never writes the image manifest.
 *
 * Usage (from web/):
 *   FREESTYLE_API_KEY=... bun scripts/probe-busybox-hmux-tui.ts [--fx]
 */
import { Freestyle, type FirewallSpec } from "freestyle";
import { hmuxTuiInstallCommand, resolveHmuxTuiSource } from "../services/vms/drivers/hmuxTuiDaemon";

const withFx = process.argv.includes("--fx");
const apiKey = process.env.FREESTYLE_API_KEY?.trim();
if (!apiKey) throw new Error("set FREESTYLE_API_KEY");

const fs = new Freestyle({ apiKey, baseUrl: process.env.FREESTYLE_API_URL?.trim() || undefined });
const firewall: FirewallSpec = { rules: [{ action: "allow", source: {}, destination: { public: true } }] };
const source = await resolveHmuxTuiSource("freestyle");
const result: Record<string, unknown> = {
  image: "freestyle/busybox",
  hmuxTuiCommit: source.commit,
  hmuxTuiSha256: source.sha256,
  fxRequested: withFx,
};

const { vm, vmId } = await fs.vms.create({
  snapshotId: "freestyle/busybox",
  displayName: "hmux BusyBox compatibility probe",
  ttlSeconds: 900,
  automaticRestart: false,
  firewall,
});

async function exec(command: string, timeoutMs = 120_000): Promise<{ code: number; output: string }> {
  const response = await vm.exec({ command, timeoutMs, linuxUser: "root" });
  const output = `${response.stdout ?? ""}${response.stderr ?? ""}`.trim();
  const code = response.statusCode ?? 124;
  console.log(`$ ${command}\n${output}\n(exit ${code})`);
  return { code, output };
}

let exitCode = 0;
try {
  const baseline = await exec("cat /etc/os-release 2>/dev/null || true; uname -a; command -v wget || true; command -v curl || true; command -v sha256sum || true; command -v systemctl || true; ls -ld /dev/pts /dev/ptmx /tmp; mount 2>/dev/null | head -20 || true; free -m 2>/dev/null || true");
  result.baseline = baseline.output;

  const install = await exec(`mkdir -p /usr/local/bin && ${hmuxTuiInstallCommand(source)}`, 180_000);
  if (install.code !== 0) throw new Error("BusyBox could not install the pinned hmux-tui binary");

  if (withFx) {
    const fx = await exec("if command -v curl >/dev/null 2>&1; then curl -fsSL --retry 2 -o /tmp/fx.tgz https://github.com/vercel-labs/fx/releases/latest/download/fx-linux-x86_64.tar.gz; else wget -q -O /tmp/fx.tgz https://github.com/vercel-labs/fx/releases/latest/download/fx-linux-x86_64.tar.gz; fi && tar -xzf /tmp/fx.tgz -C /tmp && chmod 755 /tmp/fx && /tmp/fx --version", 180_000);
    result.fx = fx.output;
    if (fx.code !== 0) console.warn("fx did not run on BusyBox; this does not affect the hmux-tui result");
  }

  const daemon = await exec("mkdir -p /tmp/hmux-state /tmp/hmux-remote; nohup env HOME=/root SHELL=/bin/sh RUST_BACKTRACE=1 RUST_LOG=debug /root/.hmux/bin/hmux-tui server start --session cloud --socket /tmp/hmux-tui-cloud.sock --state /tmp/hmux-state --remote-state-dir /tmp/hmux-remote --remote-ws 0.0.0.0:1337 --remote-ws-insecure-bind </dev/null >/tmp/hmux-tui.log 2>&1 & echo $! >/tmp/hmux-tui.pid; sleep 3; cat /tmp/hmux-tui.log; pid=$(cat /tmp/hmux-tui.pid); echo wchan=$(cat /proc/$pid/wchan 2>/dev/null || true); awk '/VmRSS|VmSize|State/ {print}' /proc/$pid/status 2>/dev/null || true; ps 2>/dev/null || true; ls -la /tmp/hmux-tui-cloud.sock 2>/dev/null || true; env HOME=/root /root/.hmux/bin/hmux-tui server status --session cloud --socket /tmp/hmux-tui-cloud.sock; awk '$2 ~ /:0539$/ && $4 == \"0A\" { found=1 } END { exit !found }' /proc/net/tcp /proc/net/tcp6", 60_000);
  result.daemon = daemon.output;
  if (daemon.code !== 0) throw new Error("BusyBox hmux-tui did not start a control socket and listener");
  result.compatible = true;
} catch (error) {
  exitCode = 1;
  result.compatible = false;
  result.failure = String(error);
} finally {
  await exec("if [ -s /tmp/hmux-tui.pid ]; then kill -TERM $(cat /tmp/hmux-tui.pid) 2>/dev/null || true; fi", 10_000).catch(() => {});
  await vm.delete().catch((error) => console.error(`failed to delete probe VM ${vmId}:`, error));
}
console.log(JSON.stringify(result, null, 2));
process.exitCode = exitCode;
