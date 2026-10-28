// Calls the hmux app's control socket through the bundled CLI (`hmux rpc`).
// The app passes HMUX_BUNDLED_CLI_PATH and HMUX_SOCKET_PATH to the sidecar it
// launches; a manually started sidecar falls back to `hmux` on PATH.

export interface HmuxRpcResult { ok: boolean; result?: unknown; error?: string }

const RPC_TIMEOUT_MS = 10_000;

export async function hmuxRpc(method: string, params: Record<string, unknown>): Promise<HmuxRpcResult> {
  const cli = process.env.HMUX_BUNDLED_CLI_PATH?.trim() || "hmux";
  let proc: ReturnType<typeof Bun.spawn>;
  try {
    proc = Bun.spawn([cli, "rpc", method, JSON.stringify(params)], {
      stdin: "ignore",
      stdout: "pipe",
      stderr: "pipe",
      env: process.env,
    });
  } catch (err) {
    return { ok: false, error: `hmux CLI unavailable: ${err instanceof Error ? err.message : String(err)}` };
  }
  const timer = setTimeout(() => proc.kill(), RPC_TIMEOUT_MS);
  try {
    const [stdout, stderr, code] = await Promise.all([
      new Response(proc.stdout as ReadableStream).text(),
      new Response(proc.stderr as ReadableStream).text(),
      proc.exited,
    ]);
    if (code !== 0) return { ok: false, error: (stderr.trim() || stdout.trim() || `hmux rpc exited ${code}`).slice(0, 300) };
    try {
      return { ok: true, result: JSON.parse(stdout) };
    } catch {
      return { ok: true, result: stdout.trim() };
    }
  } finally {
    clearTimeout(timer);
  }
}
