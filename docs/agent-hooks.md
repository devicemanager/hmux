# Agent hook integrations

hmux uses agent hooks to show running state, Feed approvals, notifications, and to restore agent sessions after a normal app relaunch.

Claude Code is handled by the hmux Claude wrapper when Claude Code integration is enabled in Settings. Other agents are installed with:

```bash
hmux hooks setup
hmux hooks setup <agent>
hmux hooks setup --agent <agent>
hmux hooks uninstall <agent>
```

Supported agent names are `codex`, `grok`, `opencode`, `pi`, `omp`, `campfire`, `amp`, `cursor`, `gemini`, `kiro`, `antigravity` (or `agy`), `rovodev` (or `rovo`), `hermes-agent`, `copilot`, `codebuddy`, `factory`, `qoder`, `kimi`, and `muse`. `hmux hooks setup` skips agents whose binary is not on `PATH` and prints a summary.

## Remote hosts

In a `hmux ssh` or `hmux mosh-tmux` workspace that uses the CLI relay, Claude Code on the remote host reports running state, notifications, and its session ID for resume through the relay. The remote `claude` shim adds the hooks with `--settings`, so it also covers launchers that pick `claude` from `PATH` with their own config directory. Permission prompts stay in Claude on the remote host. Details are in [daemon/remote/README.md](../daemon/remote/README.md#claude-code-hooks).

Claude sessions that did not start from a hmux shell, for example inside a tmux server that was already running before hmux attached to it, need the hooks in Claude's user settings instead. Run this once on the remote host, then restart those sessions:

```bash
~/.hmux/bin/hmux claude-hook install     # writes ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json
~/.hmux/bin/hmux claude-hook uninstall   # removes only the hmux entries
```

Inside tmux, these hooks report to the hmux workspace attached to the tmux session.

## Integrations

| Agent | Binary checked | Installed file | Session restore | Feed bridge |
| --- | --- | --- | --- | --- |
| Claude Code | `claude` through wrapper | wrapper-injected settings | `claude --resume <id>` | PermissionRequest |
| Codex | `codex` | `~/.codex/hooks.json`, `~/.codex/config.toml` | `codex resume <id>` | PreToolUse, PermissionRequest telemetry |
| Grok | `grok` | `~/.grok/hooks/hmux-session.json` | `grok -r <id>` | PreToolUse |
| OpenCode | `opencode` | `~/.config/opencode/plugins/hmux-session.js`, `~/.config/opencode/plugins/hmux-feed.js` | `opencode --session <id>` | plugin event bus |
| Pi | `pi` | `~/.pi/agent/extensions/hmux-session.ts` | `pi --session <id>` | tool_execution_start / tool_execution_end telemetry |
| OMP | `omp` | `~/.omp/agent/extensions/hmux-omp-session.ts`, or `$OMP_AGENT_DIR`/`$PI_CODING_AGENT_DIR` when set | `omp --session <id>` | none |
| Campfire | `campfire` | `~/.campfire/agent/extensions/hmux-campfire-session.ts` or `$CAMPFIRE_CODING_AGENT_DIR/extensions/hmux-campfire-session.ts` | `campfire --session <id>` | none |
| Amp | `amp` | `~/.config/amp/plugins/hmux-session.ts` | `amp threads continue <id>` | none |
| Cursor CLI | `cursor-agent` | `~/.cursor/hooks.json` | `cursor-agent --resume <id>` | beforeShellExecution |
| Gemini | `gemini` | `~/.gemini/settings.json` | `gemini --resume <id>` | PreToolUse |
| Kiro CLI | `kiro-cli` | `~/.kiro/agents/hmux.json` or `$KIRO_HOME/agents/hmux.json` | `kiro-cli chat --resume-id <id>` | preToolUse, postToolUse |
| Rovo Dev | `acli` | `~/.rovodev/config.yml` | `acli rovodev run --restore <id>` | none |
| Copilot | `copilot` | `~/.copilot/hooks/hmux.json` or `$COPILOT_HOME/hooks/hmux.json` | `copilot --resume <id>` | preToolUse |
| CodeBuddy | `codebuddy` | `~/.codebuddy/settings.json` | `codebuddy --resume <id>` | PreToolUse |
| Factory | `droid` | `~/.factory/settings.json` | `droid --resume <id>` | PreToolUse |
| Qoder | `qodercli` | `~/.qoder/settings.json` | `qodercli --resume <id>` | PreToolUse |
| Kimi Code | `kimi` | `~/.kimi-code/config.toml` or `~/.kimi/config.toml` | `kimi --resume <id>` | PreToolUse, PostToolUse |
| Muse Code | `muse` | `~/.config/muse/settings.json` or `$XDG_CONFIG_HOME/muse/settings.json` | `muse resume <id>` | none |
| Antigravity | `agy` | `~/.gemini/config/hooks.json` (`hmux` hook group) | `agy --conversation <id>` | none |

Kimi Code resumes with the captured executable and working directory, preserving supported
model and configuration options. Prompts, old session selectors, and noninteractive commands
are omitted by the sanitizer described below.

OpenCode also supports project-local Feed installation:

```bash
hmux hooks opencode install --project
```

That writes `.opencode/plugins/hmux-feed.js` in the current directory.

## What the hooks record

Session hooks write `~/.hmuxterm/<agent>-hook-sessions.json`. Each entry stores the agent session ID, hmux workspace ID, surface ID, cwd, process ID when available, current lifecycle (`running`, `idle`, `needsInput`, or `unknown`), and a sanitized launch command. On app relaunch, hmux rebuilds each workspace and runs the agent's native resume command with the saved session ID.

The sanitizer preserves model, sandbox, config, and cwd-related flags. It drops prompts, credentials, old session selectors, and noninteractive commands so relaunch resumes the session instead of starting a new task or leaking secrets.

Claude Code's `PushNotification` tool (model-initiated "notify the user now" pushes) is bridged through a `PostToolUse` hook into hmux notifications. The tool normally delivers via a raw OSC desktop notification, which hmux suppresses on surfaces running a hook-integrated agent, so the bridge is what makes those pushes visible inside hmux. It mirrors the tool's own outcome: a push the tool reports as skipped (user active, channel disabled) is not duplicated.

Grok uses its `Notification` hook for user-facing completion messages. hmux records `Stop` as idle state, but leaves the visible notification text to the `Notification` payload so repeated turns keep Grok's own message instead of a generic completion fallback.

## Workspace auto-naming

When the opt-in `automation.workspaceAutoNaming` setting is enabled, turn-end hooks also drive AI naming of workspaces and tabs. Supported adapters are Claude Code, Codex, Grok, OpenCode, Pi, and OMP; each adapter gates on the live setting over the socket, reuses the session store above for throttle state, summarizes with that agent's own CLI in a no-tools or isolated headless mode, and never overwrites a name the user set. Gemini, Amp, Cursor, Antigravity, Kiro, Rovo Dev, Hermes Agent, Copilot, CodeBuddy, Factory, and Qoder are skipped until they have both a verified conversation source and a safe cheap non-interactive summarizer runner. See [workspace-auto-naming.md](workspace-auto-naming.md).

## Agent Hibernation

Agent Hibernation kills idle background agent processes to free their RAM and CPU, then resumes each one with its saved session when you return to its tab. Routine hibernation based on the live-terminal limit is opt-in and off by default. A separate safety path remains active under memory pressure, even when routine hibernation is off. hmux knows which process belongs to which terminal because the agent hooks associate each session ID with its surface (see the session-restore section above), so it can terminate the right process and bring back the right session.

### When a terminal hibernates

For routine hibernation, a live terminal is only a candidate when all of these hold:

- it has a saved restorable agent session, and the saved launch data can relaunch it the way it was started (a Claude session needs its captured launch arguments, so a `sr claude proxy` launch resumes through `sr`; a declared `agents.launchers` entry must still resolve)
- the agent lifecycle is `idle` (not running, not waiting on input)
- the terminal is in the background (its panel is not currently visible)
- you have more live restorable agent terminals than the live-terminal limit (`maxLiveTerminals`, default `12`)
- the terminal has had no output, input, or lifecycle change for at least the idle window (`idleSeconds`, default `5`)
- the agent has no background work still running: no shell it started after launch is alive, and its Claude transcript shows no unfinished `run_in_background` command, Monitor, or async subagent

The live-terminal limit is the first gate. Under the limit, nothing hibernates no matter how long it sits idle. Once you are over the limit, hmux frees only the oldest-idle background terminals, just enough to get back under the limit. Visible terminals are never touched.

Before killing, hmux watches the terminal tail. It samples the last lines of output and a fingerprint of the process, and waits a short confirmation window (`confirmationSeconds`, ~60s) during which the output and process must stay unchanged. Any new output, input, lifecycle change, or PID change cancels the pending hibernation. This is why a small `idleSeconds` is safe: a freshly idle agent that resumes work on its own is never killed mid-task.

So with the defaults, routine hibernation only affects power users running more than 12 agents at once, and even then only ~1 minute after an agent has gone quiet off-screen.

### Memory pressure

Under memory pressure, hmux can run the same protected teardown path independently of the `enabled` setting and live-terminal limit. It runs on critical memory pressure (macOS reports critical pressure, which hmux holds for 120 s, or the hmux app process's own footprint reaches 16 GiB), and when hmux's total memory use (the hmux process and its descendants) passes its aggregate warning threshold, 50% of physical memory (see [configuration.md](configuration.md#aggregate-memory-pressure-safety-policy)). Each pass considers every eligible background agent; the live-terminal limit does not apply. The agent must still be restorable, off-screen, explicitly idle, free of unconfirmed input, stable through the confirmation window, and backed by a transcript hmux can protect. Visible, running, needs-input, recently changed, or unprotectable agents are never selected. Before signaling anything, hmux revalidates the exact process generation and workspace/surface scope.

### What gets killed and how it comes back

hmux sends `SIGTERM` to the agent's process group (scoped to that workspace and surface), then swaps the live terminal for a lightweight placeholder, releasing the terminal's memory and CPU. When you visit the tab again, hmux runs the agent's native resume command with the saved session ID, so the session continues where it left off. The placeholder also shows a Resume button as a manual fallback.

### Hibernate or wake one agent

```bash
hmux agent hibernate surface:3     # or: hmux agent-hibernation hibernate surface:3
hmux agent wake surface:3
```

`hibernate` stops one agent now, whether or not routine hibernation is on. It skips the idle delay, the live-terminal limit and the confirmation window, and keeps every other check. The agent must be off screen and idle, with no unsent input and no background work. hmux still snapshots the transcript and revalidates the process before it signals anything. When a check fails, the command exits non-zero and says why. `wake` resumes a hibernated agent in place without moving focus. Both accept a surface UUID, a ref, or an index with `--workspace`, and `--json`. Over the socket they are `agent.hibernate` and `agent.wake` with `surface_id`.

After a wake, hmux checks that the agent actually came back. The wake counts as working as soon as either the agent's own hooks report in for that terminal or a live process of that agent is found running in it (hmux looks every few seconds, which covers agents without hooks). If the resume command exits before either happens, or neither happens within 90 seconds, the terminal shows a banner saying the agent didn't resume, with **Retry** (types the resume command again), **Show command** (shows the command so you can copy it) and a close button. The workspace's sidebar row shows "Agent didn't resume" until the failure is retried, dismissed, or the agent reports in, and one entry is added to the notification feed. The sidebar row is not saved with the session.

### Enable and configure

Enable routine hibernation from the command palette (`⌘⇧P` -> **Enable Agent Hibernation**), from **Settings > Terminal > Agent Hibernation**, or from the CLI:

```bash
hmux agent-hibernation on
hmux agent-hibernation off
```

Tune the idle window and live-terminal limit from Settings, or set them in `~/.config/hmux/hmux.json`:

```json
{
  "terminal": {
    "agentHibernation": {
      "enabled": true,
      "idleSeconds": 5,
      "maxLiveTerminals": 12
    }
  }
}
```

- `idleSeconds` (default `5`, range `5`-`604800`): how long a background idle agent terminal must be quiet before it can hibernate. Raise it to keep agents alive longer; lower it to reclaim resources sooner. The `confirmationSeconds` settle window still applies on top of this.
- `maxLiveTerminals` (default `12`, range `1`-`256`): how many live restorable agent terminals to keep before hmux hibernates the oldest idle background ones. Lower it to hibernate more aggressively; raise it to keep more agents live.

## Custom surface resume commands

Use `hmux surface resume set --shell <command>` to attach a resume command to the current terminal surface. Public CLI and socket-created commands are kept for inspection and manual restore by default. To auto-run one on restore, set it from the terminal's **Resume Commands** context menu and approve the prompt, or change its signed command prefix in **Settings > Terminal > Resume Commands**. A CLI or socket request never shows that prompt; its reply carries `approval_required: true` when the command still needs approval in hmux.

Approvals are prefix-based and signed by hmux. They also bind the working directory and exact environment values when present. A process can propose a command, but it cannot make that command sticky without the user choosing Auto-Restore or Ask Each Time in hmux.

Agent hooks publish their own bindings with automatic resume already granted. A later `--source agent-hook` write for the same session that omits automatic resume (for example, an older Pi extension re-publishing through `hmux surface resume set`) does not downgrade that binding: hmux keeps the trusted binding and returns it as the result.

## Disable automatic resume

To restore panes without automatically restarting saved agent sessions, turn off
**Settings > Terminal > Resume Agent Sessions on Reopen**.

You can also set the same preference in `~/.config/hmux/hmux.json`:

```json
{
  "terminal": {
    "autoResumeAgentSessions": false
  }
}
```

When this is off, hmux still restores the saved window, workspace, pane, scrollback,
and browser state. Restored agent terminals stay idle until you resume them manually.

## Codex wrapper precedence

When hmux launches Codex and at least one hmux event is not already covered by
a persistent hmux handler in `hooks.json`, the wrapper adds `--enable hooks`,
`--dangerously-bypass-hook-trust`, and one `-c hooks.<event>=...` value per
uncovered event, for that invocation only. When `hmux hooks codex install` has
already installed every hmux handler, the wrapper adds nothing, which also
keeps an intentional `features.hooks = false` intact.

Codex discovers hooks per configuration layer and appends them from lowest to
highest precedence: the user `hooks.json` and `[hooks]` table in `config.toml`
(under `~/.codex` or `$CODEX_HOME`), a trusted project's `.codex/hooks.json`
and `.codex/config.toml`, and finally the session flags hmux injects. A
`-c hooks.<event>=` value only defines that session-flags layer, so user and
project handlers are registered before hmux's handler and nothing in
`hooks.json` or `config.toml` is replaced or rewritten. Codex dispatches an
event's handlers together and orders only their results, so nothing may depend
on hmux's handler running first or last. hmux deliberately does not copy user
handlers into its own value: Codex would discover the copy as a second handler
and run it twice. This contract was verified by hand against codex-cli 0.146.0
and 0.153.4, and `tests/test_codex_wrapper_hook_append.py` repeats the check
against the installed `codex` binary with a local fake model provider.

Two trade-offs apply whenever the wrapper injects. `--dangerously-bypass-hook-trust`
skips Codex's hook review for the whole process, so user and project handlers
run without the trust prompt. Session flags form one layer, so a
`-c hooks.<event>=` value you pass to `codex` yourself is applied after hmux's
and replaces hmux's handler for that event only; use `hmux hooks codex install`
when you need both.

Set `HMUX_CODEX_HOOKS_DISABLED=1` for a launch to keep Codex's configuration
entirely untouched. This preserves user hook behavior and Codex's own trust
review, but also disables hmux's Codex lifecycle registration, Feed and
notification bridge, rebinding, and hibernation integration for that process.

## Environment overrides

| Agent | Config directory override | Disable hmux hooks for one process |
| --- | --- | --- |
| Codex | `CODEX_HOME` | `HMUX_CODEX_HOOKS_DISABLED=1` |
| Grok | `GROK_HOME` | `HMUX_GROK_HOOKS_DISABLED=1` |
| OpenCode | `OPENCODE_CONFIG_DIR`, then `XDG_CONFIG_HOME`; `OPENCODE_DB`, then `XDG_DATA_HOME`, for the sessions database. A restored session replays these, `OPENCODE_CONFIG` and `XDG_STATE_HOME` when they are absolute paths | `HMUX_OPENCODE_HOOKS_DISABLED=1` |
| Pi | `PI_CODING_AGENT_DIR` | `HMUX_PI_HOOKS_DISABLED=1` |
| OMP | `OMP_AGENT_DIR` for the full agent directory, then `PI_CODING_AGENT_DIR`; otherwise `PI_CONFIG_DIR` for the config root | `HMUX_OMP_HOOKS_DISABLED=1` |
| Campfire | `CAMPFIRE_CODING_AGENT_DIR` | `HMUX_CAMPFIRE_HOOKS_DISABLED=1` |
| Amp | none | `HMUX_AMP_HOOKS_DISABLED=1` |
| Cursor CLI | none | `HMUX_CURSOR_HOOKS_DISABLED=1` |
| Gemini | none | `HMUX_GEMINI_HOOKS_DISABLED=1` |
| Kiro CLI | `KIRO_HOME` | `HMUX_KIRO_HOOKS_DISABLED=1` |
| Kimi Code | `KIMI_CODE_HOME`, `KIMI_SHARE_DIR` | `HMUX_KIMI_HOOKS_DISABLED=1` |
| Muse Code | `XDG_CONFIG_HOME` | `HMUX_MUSE_HOOKS_DISABLED=1` stops the `muse` wrapper from installing hooks; Muse hides hmux variables from hooks, so run `hmux hooks muse uninstall` to turn installed hooks off |
| Rovo Dev | none | `HMUX_ROVODEV_HOOKS_DISABLED=1` |
| Copilot | `COPILOT_HOME` | `HMUX_COPILOT_HOOKS_DISABLED=1` |
| CodeBuddy | `CODEBUDDY_CONFIG_DIR` | `HMUX_CODEBUDDY_HOOKS_DISABLED=1` |
| Factory | none | `HMUX_FACTORY_HOOKS_DISABLED=1` |
| Qoder | `QODER_CONFIG_DIR` | `HMUX_QODER_HOOKS_DISABLED=1` |
| Antigravity | none | `HMUX_ANTIGRAVITY_HOOKS_DISABLED=1` |

Muse Code runs hooks through the user's login shell with a cleared environment, so the hmux `muse` wrapper installs each hook as a `#!/bin/sh` script under `~/.hmux/hooks/muse/` that carries the installing hmux CLI and socket and finds the terminal from the Muse process, like Grok. Muse sessions appear in Vault from Muse's own `session-index.db`.

Pi uses Pi's extension system, not the legacy Pi hooks API. The installed extension is auto-discovered from `~/.pi/agent/extensions/` or `$PI_CODING_AGENT_DIR/extensions/`.

OMP uses OMP's native extension system. OMP native extension discovery scans `${PI_CODING_AGENT_DIR:-~/${PI_CONFIG_DIR:-.omp}/agent}/extensions/`, so hmux installs OMP's extension with a distinct `hmux-omp-session.ts` filename and does not reuse Pi's `hmux-session.ts`.

Campfire ships this integration natively: current campfire versions include a built-in hmux bridge, so no install step is needed (like Claude Code via the hmux wrapper) — `hmux hooks campfire install` exists for older campfire versions, and the installed extension defers to the native bridge when both are present. Campfire embeds vanilla Pi under a `.campfire` white-label, so its extension discovery scans `${CAMPFIRE_CODING_AGENT_DIR:-~/.campfire/agent}/extensions/`. The hmux extension records only the HOST role (`CAMPFIRE_SESSION_ROLE=host`); a joiner is an ephemeral view whose argv carries the invite URL — a capability token that is never persisted or replayed. The extension also subscribes to campfire's in-process observer bridge and surfaces driver-actionable collaborative moments (a joiner waiting in the lobby, a capability ask) as hmux notifications.

Kiro stores hooks inside agent configuration files. The hmux installer creates or updates a `hmux` agent config with lifecycle, tool, and completion hooks; merge the generated `hooks` block into another Kiro agent config if you want the same hmux notifications on that agent.

Kiro Feed verbosity follows **Settings > Automation > Kiro Notification Level** or `automation.kiroNotificationLevel` in `hmux.json`. `minimal` keeps actionable approval cards only, `standard` also keeps mutating tool events, and `verbose` keeps every Kiro tool event.

Kimi ships under two config layouts: Kimi Code CLI reads `${KIMI_CODE_HOME:-~/.kimi-code}/config.toml`, and Kimi CLI 1.49 and earlier read `${KIMI_SHARE_DIR:-~/.kimi}/config.toml`. hmux installs into the file the installed binary reports through `kimi doctor`; when the binary cannot answer, it installs into the first of those two locations that already exists, defaulting to the Kimi Code CLI path. The other location is never emptied by setup: an existing hmux block there is refreshed in place so a second Kimi install keeps working, and a config without a hmux block is left untouched. `hmux hooks uninstall kimi` removes the block from both. Unrelated TOML and third-party hooks are preserved everywhere.

Antigravity (`agy`) hooks are written as the `hmux` group of `~/.gemini/config/hooks.json`. Each hook command first uses the hmux that owns the terminal the session runs in (`HMUX_BUNDLED_CLI_PATH` and `HMUX_SOCKET_PATH` from that terminal's environment), so sessions started from different hmux builds (stable, nightly, tagged dev builds) each report to their own app and restore correctly. When `agy` runs a hook without that environment, the command falls back to the hmux build that installed it. Re-run `hmux hooks agy install --yes` from an up-to-date hmux to refresh that fallback.

## Troubleshooting

Run `hmux hooks <agent> install --yes` to reinstall one integration. Run `hmux hooks <agent> uninstall --yes` before editing generated files by hand.

If Feed shows nothing, confirm the terminal has `HMUX_SURFACE_ID` and the hook file contains a `hmux hooks feed --source <agent>` command, generated extension bridge, or OpenCode feed plugin. Pi reports non-blocking tool execution telemetry through its generated extension. OMP, Campfire, and Rovo Dev currently provide lifecycle and restore hooks only, so they do not create Feed approval cards. Amp's bundled plugin reports live tab-status updates (idle / thinking / running / reading / done / error / interrupted) and lifecycle restore but does not create Feed approval cards.

If relaunch does not resume an agent, first run `hmux sessions --agent <name> --json` to inspect the saved session without a running hmux socket. If needed, check `~/.hmuxterm/<agent>-hook-sessions.json` and verify the agent's resume command still works outside hmux.
