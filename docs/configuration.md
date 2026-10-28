# hmux.json settings

Global app preferences live in `~/.config/hmux/hmux.json`.

For themes, fonts, transparency, and other appearance settings across Ghostty config and `hmux.json`, see [Customizing hmux's look](customizing-appearance.md).

## Automation socket trust boundary

`hmuxOnly` allows the hmux CLI and programs started from hmux terminals. This
uses the process ancestry of the caller, so a program launched inside a hmux
terminal is trusted even when it later starts another process or leaves the
terminal's original process group. Use `password` or `hmuxOnly` when untrusted
code may run inside a hmux terminal. `allowAll` also grants
access to other local macOS users and is unsafe on a shared Mac.

## Ghostty config live reload

hmux reads terminal settings from the Ghostty config: `~/.config/ghostty/config` and
`~/.config/ghostty/config.ghostty` (under `$XDG_CONFIG_HOME/ghostty/` when that is set),
`~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`
(or its legacy `config`), and the hmux config under
`~/Library/Application Support/com.hmuxterm.app/`. hmux watches these files, every file
pulled in with `config-file`, and user theme files named by `theme` (an absolute path, or
`$XDG_CONFIG_HOME/ghostty/themes/<name>`, which defaults to `~/.config/ghostty/themes/<name>`,
for each side of a `light:…,dark:…` pair). Saving one of them reloads the
configuration the same way as Reload Configuration (Cmd+Shift+,), about 300 ms after
the last write. Atomic saves, Vim-style saves that move the old file aside, files
created after launch, and newly added includes are all picked up. A save that leaves
the contents unchanged, or a file hmux already reloaded itself (for example after
`hmux themes set` or a `hmux themes` preview), does not trigger another reload. A save
made while a reload is still applying reloads once more after it. Themes bundled with hmux or Ghostty.app
are not watched.

When Ghostty reports errors for the config (an unknown key, an invalid value, a missing
theme), hmux shows a notice in the corner of the window listing the first three, with a
button that opens the file at the offending line. The notice appears once per distinct set
of errors: reloads that keep the same errors stay quiet, fixing them hides the notice, and
reintroducing an error shows it again. `hmux config doctor` validates `hmux.json` only.

## `mobile.artifactFolderAccess`

Controls which files and folders hmux on iOS may browse after a chat references a directory or a directory path appears in a terminal.

```json
{
  "mobile": {
    "artifactFolderAccess": "subtree"
  }
}
```

- `subtree` (default): authorize the referenced directory and its full subtree.
- `oneLevel`: preserve the previous rule, authorizing only immediate children and listing only the referenced directory itself.

Authorization compares canonical paths after resolving symlinks. A symlink inside an authorized folder cannot grant access to a target outside that folder.

## `mobile.browserTunnel.allowOtherHosts`

Controls where the iOS "On iPhone" browser can reach through this Mac. The browser loads pages on the phone, and connections for this Mac's workspaces leave from this Mac.

```json
{
  "mobile": {
    "browserTunnel": {
      "allowOtherHosts": false
    }
  }
}
```

- `false` (default): only this Mac's `localhost` (`localhost`, `*.localhost`, `127.0.0.0/8`, `::1`) is reachable through the Mac. Other sites load over the phone's own network.
- `true`: LAN, VPN, and internet hosts are also reachable through this Mac, with names resolved on this Mac.

Link-local addresses, including the cloud metadata service at `169.254.169.254`, never go through this Mac either way; the phone loads those over its own network, as it does any host this Mac refuses. Only a phone signed in to the same account and admitted to this Mac can open connections, and they end when that phone disconnects. Turning off the embedded browser by configuration profile turns this off too.

## `paneBorderColor` and `activePaneBorderColor`

Customize split-workspace pane boundaries controlled by hmux.

```json
{
  "paneBorderColor": "#6B7280",
  "activePaneBorderColor": "#3B82F6"
}
```

- `paneBorderColor`: overrides the divider color between hmux panes in split workspaces.
- `activePaneBorderColor`: draws a border around the focused hmux pane in split workspaces.

Both settings accept 6-digit hex colors (`#RRGGBB`). Omit a key, or set it to `null`, to use the default. These settings apply to hmux's multi-surface pane layout. When `paneBorderColor` is unset, the divider uses Ghostty's `split-divider-color` if one is configured.

## `app.windowTitleTemplate`

Opt-in template for the macOS `NSWindow.title`. Leave it unset or set it to an empty string to keep the default behavior, where the title follows the active workspace title or current directory.

```json
{
  "app": {
    "windowTitleTemplate": "[hmux:{windowToken}] {activeWorkspace}"
  }
}
```

Supported placeholders:

- `{windowId}`: the persisted per-window UUID.
- `{windowToken}`: the first 8 characters of the persisted window UUID.
- `{activeWorkspace}`: the active workspace title, falling back to the default title when the workspace title is blank.
- `{activeDirectory}`: the active workspace's current directory.
- `{defaultTitle}`: the title hmux would have used without a template. For `hmux ssh` and Cloud workspaces it ends with the host, as in `build · big-red`.
- `{appName}`: `hmux`.

For tiling window managers such as AeroSpace or yabai, match on the stable token in the title. For example, the template above gives each restored macOS window a title containing `[hmux:abcd1234]`, so a rule can match `\\[hmux:abcd1234\\]`. The token is stable across relaunches for restored windows because it comes from the persisted window UUID.

## `app.confirmQuit`

Controls when hmux asks before quitting:

- `always`: show the quit confirmation on Cmd+Q or app quit.
- `dirty-only`: show it only when a workspace has a terminal or panel that reports close confirmation is needed.
- `never`: quit immediately.

Default: `always` for stable, nightly, and RC builds. DEV builds always behave as `never`, regardless of the file setting, so tagged development builds can be replaced without a full-screen quit dialog.

The older boolean `app.warnBeforeQuit` still works as a fallback when `app.confirmQuit` is not set. `true` maps to `always`; `false` maps to `never`.

## `app.forkConversationDefaultDestination`

Controls what the tab right-click `Fork Conversation` item does. The submenu still exposes every destination.

Values: `right`, `left`, `top`, `bottom`, `newTab`, `newWorkspace`.

Default: `right`.

## `terminal.agentHibernation`

Routine Agent Hibernation is opt-in. hmux hibernates idle background agent
processes to free RAM and CPU, then resumes each one with its saved session
when you visit its tab. Independently, memory pressure (critical system pressure,
or aggregate pressure below) can use the same lossless hibernation lifecycle even
when routine hibernation is disabled.
See [agent-hooks.md](agent-hooks.md#agent-hibernation) for the full eligibility
rules, confirmation settle window, and resume behavior.

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

- `enabled`: turn routine Agent Hibernation on. Default: `false`. Aggregate-pressure safety hibernation remains available when this is `false`.
- `idleSeconds`: seconds a background idle agent terminal must be quiet before it can hibernate. A ~60s confirmation settle window still applies on top of this. Default: `5`. Range: `5`-`604800`.
- `maxLiveTerminals`: the target used only by opt-in routine hibernation before it hibernates the oldest idle background terminals. It is not a global memory or agent limit, and aggregate-pressure handling does not use it. Default: `12`. Range: `1`-`256`.

### Aggregate memory-pressure safety policy

hmux prefers macOS's resource-coalition physical footprint, which includes the
hmux process and its descendants. The private coalition layout is enabled only
on OS releases with a validated ABI; if the API or validation is unavailable,
hmux uses a complete, de-duplicated descendant process tree. An incomplete
listing is treated as unavailable and cannot authorize hibernation. Relative
percentages (warning at 50% and critical at 70% of installed physical memory,
with an optional 20%/10% available-memory corroboration) decide only when to
offer the idle-only pass. They are signals, not a memory ceiling or a limit on hmux.

While the same complete pressure remains through the existing
confirmation window, hmux considers every currently eligible idle, non-visible
agent through the ordinary lossless Agent Hibernation lifecycle. The scheduled
routine pass retains its oldest-activity ordering; the pressure pass considers
all eligible agents, so its encounter order does not limit or prioritize which
agents are eligible. The existing `idle` lifecycle state, terminal-input check,
transcript/process identity validation, and visible-panel protection remain
required; if those proofs are unavailable, that candidate is left running. This
policy never caps memory use, caps the number of agents/panes/processes,
throttles or blocks new work, or terminates active or visible work. Hibernated
agents resume from their saved session exactly as routine Agent Hibernation does.

Enable routine hibernation from the command palette (`⌘⇧P` -> Enable Agent Hibernation), from **Settings > Terminal > Agent Hibernation**, or with `hmux agent-hibernation on`.

## `sidebar.showAgentActivity`

Shows a loading spinner on sidebar workspace rows that currently have running coding agents or active manual loaders (`hmux workspace loading on`).

```json
{
  "sidebar": {
    "showAgentActivity": true,
    "loadingSpinnerPosition": "leading",
    "notificationBadgePosition": "leading"
  }
}
```

- `showAgentActivity`: show the spinner at all. Default: `true`. It is a live status signal, so it stays visible even when `sidebar.hideAllDetails` is on. Toggle it from **Settings > Sidebar > Show Loading Spinner**.
- `loadingSpinnerPosition`: `leading` (left, sharing the unread-badge slot) or `trailing` (right, in the close-button corner). Default: `leading`.
- `notificationBadgePosition`: which side the unread notification badge sits on, `leading` or `trailing`. Default: `leading`.

The spinner is compositor-driven (a Core Animation transform run by the render server), so it costs no per-frame CPU and pauses automatically while the window is occluded or Reduce Motion is on. Toggle it manually per workspace with `hmux workspace loading <on|off> [--id <name>]`; each `--id` is a separate loader and the command prints the workspace state as `before=ON;after=OFF`.

## `sidebar.compactAgentStatus`

Puts the workspace's own status on one line, like the Claude desktop session list: one small colored glyph, then the title. Agent hooks report each coding agent's state as a status entry (for example Claude Code's "Running" or "Needs input"), and by default every one gets its own row under the workspace title, next to the branch and directory line and the pull request rows. With `compactAgentStatus` on, those rows fold into the glyph, along with the notification preview, the unread count badge and the loading spinner, and a long title stops wrapping. Hover the glyph for the agent, pull request, branch, and directory details, plus the config profile an agent launched under when it isn't the default (`CLAUDE_CONFIG_DIR=~/.claude-outlook` shows as `outlook`).

Lines you added yourself stay where they are: the workspace description, your own `hmux set-status` keys, logs, progress, ports, the checklist, and a remote workspace's connection row with its Reconnect button. So `hmux set-status` under your own key is still the way to keep a line of your own in compact mode.

```json
{
  "sidebar": {
    "compactAgentStatus": true
  }
}
```

The glyph shows the loudest state that applies:

| State | Glyph |
| --- | --- |
| An agent reported an error | red warning triangle |
| An agent needs input | amber dot |
| An agent is running through subagents | pulsing gray connected-points glyph |
| An agent is waiting on a background command, a scheduled wakeup or a CI run | gray hourglass |
| An agent is running | pulsing gray dot, in place of the loading spinner |
| An agent is starting (no state reported yet) | dashed ring |
| Unread notifications | blue dot, in place of the unread count badge |
| Open pull request | gray pull request glyph |
| Merged pull request | purple merge glyph |
| Closed pull request | gray pull request glyph with a minus badge |
| Agent idle (done, seen) | gray checkmark |
| Branch, no pull request | gray branch glyph |
| Plain terminal | none; the title starts at the row's edge |

The hourglass only goes up when every running agent in the workspace reported that it is waiting, so a second agent still working keeps the row running.

hmux does not fetch a pull request's checks or mergeability, so an open pull request is gray whatever CI says. A pull request whose state repeated refresh failures could not confirm does not set the glyph at all.

Change any of them with `sidebar.compactStatusIcons`, a map from state to an [SF Symbol](https://developer.apple.com/sf-symbols/) name. The states are `error`, `needsInput`, `subagents`, `running`, `waiting`, `starting`, `unseen`, `pullRequestOpen`, `pullRequestMerged`, `pullRequestClosed`, `idle`, `branch` and `terminal`. Colors stay the same; a configured symbol replaces the badge too, draws at full size, and a name that does not render falls back to the built-in symbol. The built-in pull request and merge glyphs are drawn by hmux, since the SF Symbols ones are too narrow at sidebar size; name them `hmux.pullrequest` and `hmux.merge` to use them for another state.

```json
{
  "sidebar": {
    "compactAgentStatus": true,
    "compactStatusIcons": {
      "terminal": "apple.terminal",
      "needsInput": "hand.raised.fill",
      "idle": "moon.zzz"
    }
  }
}
```

- Default: `false`.
- Only agent-owned status keys lose their rows (`claude_code`, `codex`, and the other built-in agent integrations). Status set with `hmux set-status` under any other key keeps its row.
- The notification preview moves to the top of the tooltip too. Rows you added yourself (a workspace description, `hmux set-status` under other keys, logs, progress, ports) keep their lines.
- Workspace group headers show a glyph, after the group name, for the workspaces without a row of their own: the anchor workspace while the group is expanded, and every member once it is collapsed. Only states that ask for attention appear there (error, needs input, running, unread), the loudest first; hover it to see which workspace each comes from. It replaces the header's unread count.
- The pulse is a Core Animation opacity loop capped at 30 Hz. It stops while the window is hidden or occluded, and Reduce Motion keeps the dot still.
- A pull request glyph shows whether the pull request is open, merged or closed, and nothing about its checks. hmux does not fetch CI status or mergeability for a pull request, so there is no passing, failing or conflict glyph: adding one would advertise a color no user could see. An open pull request shows gray, merged shows purple, and closed shows gray with a minus badge. See [#12807](https://github.com/manaflow-ai/cmux/issues/12807).
- Pull request and branch details follow `sidebar.showPullRequests` and the git branch toggle: turn either off and the glyph ignores it. Toggle compact status from **Settings > Sidebar > Compact Agent Status**.

## `terminal.showTextBoxOnNewTerminals` and `terminal.focusTextBoxOnNewTerminals`

`terminal.showTextBoxOnNewTerminals` opens the TextBox on newly-created terminal sessions without moving keyboard focus into it.

`terminal.focusTextBoxOnNewTerminals` opens the TextBox and focuses it for foreground terminal sessions created from the app UI, such as new terminal workspaces, tabs, and splits. Terminals created through the hmux CLI/control socket do not auto-focus the TextBox, even when this setting is enabled, so background automation does not steal keyboard focus.

## Workspace terminal font size shortcuts

Cmd+Ctrl+= and Cmd+Ctrl+- increase or decrease every terminal in the selected workspace by one point. Cmd+Ctrl+0 resets them to the current Ghostty font size. Hidden, hibernated, and Dock terminals change with visible terminals, and newly created terminals inherit the workspace size. Rebind them with `shortcuts.bindings.increaseWorkspaceTerminalFontSize`, `shortcuts.bindings.decreaseWorkspaceTerminalFontSize`, and `shortcuts.bindings.resetWorkspaceTerminalFontSize`.

## New Cloud Workspace shortcut and the plus-button menu

Cmd+Y creates a workspace on the machine that owns the most recently selected Cloud workspace, or the first usable machine in the right-hand Cloud sidebar. If no usable Cloud workspace or machine is available, it opens the New Cloud Machine flow. When a remembered selection is stale, the resolver uses the current right-hand Cloud sidebar order, including pins and manual reordering; an empty or still-loading fleet deterministically stays on the New Cloud Machine flow. Cmd+Shift+Y always opens the New Cloud Machine flow. Cmd+N always creates a local workspace on this Mac. Rebind or unbind these shortcuts from Settings > Keyboard Shortcuts or with `shortcuts.bindings.newCloudWorkspace` and `shortcuts.bindings.newCloudMachine`.

When `ui.newWorkspace.contextMenu` is not set, the plus-button menu lists `hmux.newWorkspace` (Cmd+N, local), `hmux.newCloudWorkspace` (Cmd+Y), `hmux.newCloudMachine` (Cmd+Shift+Y), `hmux.newTerminal` (Cmd+T), and `hmux.newBrowser` (Cmd+Shift+L). Each row shows its current shortcut, so a rebind in Settings or `hmux.json` appears the next time the menu opens; unbound and chord shortcuts show no hint. Cloud rows appear only when Cloud Machines is enabled. A configured menu keeps your order and still shows hints for built-in rows and for actions with a `shortcut`.

## `terminal.textBoxSubmitActions`

Controls what the TextBox submit button does for new terminal sessions. Active agent sessions such as Claude, Codex, OpenCode, and Pi always use plain Text Entry so prompts go into the running agent instead of launching another command.

Press Shift-Tab in the TextBox to cycle the default action. This shortcut is `shortcuts.bindings.cycleTextBoxSubmitAction`; rebind or disable it from Settings > Keyboard Shortcuts or `hmux.json`. Right-click the submit button to pick any configured action or open this documentation.

```json
{
  "terminal": {
    "textBoxDefaultSubmitAction": "codex",
    "textBoxSubmitActions": [
      {
        "id": "codex",
        "title": "Codex --yolo",
        "kind": "commandTemplate",
        "commandTemplate": "codex --yolo -- {{prompt}}",
        "systemImage": "sparkles",
        "assetName": "AgentIcons/Codex",
        "backgroundColorHex": "#8FDBFF"
      },
      {
        "id": "custom-router",
        "title": "Custom Router",
        "kind": "commandTemplate",
        "commandTemplate": "agent-router --plan {{prompt}}",
        "systemImage": "wand.and.stars",
        "imagePath": "~/Pictures/router.png",
        "backgroundColorHex": "#3DDC97"
      }
    ]
  }
}
```

Built-in action IDs: `claude`, `codex`, `opencode`, `pi`.

Set `textBoxDefaultSubmitAction` to `text-entry` to force plain Text Entry for new terminals.
Built-in provider actions shell-quote `{{prompt}}` before pasting the command. Claude may still show its workspace trust prompt before processing the prompt. Built-ins run `claude --dangerously-skip-permissions -- {{prompt}}`, `codex --yolo -- {{prompt}}`, `opencode --prompt {{prompt}}`, and `pi -- {{prompt}}`.

Action fields:

- `id`: stable action ID.
- `title`: menu label for custom actions.
- `kind`: `textEntry` or `commandTemplate`.
- `commandTemplate`: shell command for `commandTemplate`. Include `{{prompt}}` where the prompt should be shell-quoted into the command line.
- `preservePromptAfterLaunch`: optional boolean for custom launch-only actions. When `true`, hmux submits `commandTemplate` as a provider launch command while keeping the TextBox prompt intact for the active agent session.
- `systemImage`: fallback SF Symbol name shown on the submit button.
- `assetName`: optional app asset catalog image name, for example `AgentIcons/Codex`.
- `imagePath`: optional PNG or image path for the submit button.
- `backgroundColorHex`: action color metadata as RGB or RGBA hex. The submit button fill stays white and only changes opacity between enabled and disabled states.

## `terminal.uploadCommands`

Replace the built-in `scp` for terminal file drops and pastes over SSH with a
command you choose. When you drop or paste a file into a terminal running an SSH
session, hmux normally `scp`s it into a private directory on the host,
`~/.cache/hmux/paste/<session>/hmux-paste-<uuid>.<ext>`, and types the remote
path. `terminal.uploadCommands` is an ordered list of host-scoped
rules; when the ssh destination matches a rule, hmux runs that rule's command
instead and inserts what the command prints.

```json
{
  "terminal": {
    "uploadCommands": [
      {
        "hostPattern": "*.example.com",
        "command": "my-upload \"$HMUX_UPLOAD_LOCAL_PATH\" \"$HMUX_UPLOAD_DESTINATION:$HMUX_UPLOAD_REMOTE_PATH\""
      }
    ]
  }
}
```

- `hostPattern`: an fnmatch glob matched against the ssh destination (`user@` and
  IPv6 brackets stripped, then lowercased) — the same glob style as a single
  `ssh_config` `Host` pattern (`*`, `?`; no pattern lists or `!` negation). Omit
  it, or set it to `null`, for a catch-all. When the session carries a `HostName`
  ssh option (for example a connection through a ProxyCommand broker dialled as
  `localhost`), a rule also matches that resolved host, so a pattern written
  against either the alias or the real host works.
- `command`: run through `/bin/sh -c`, **once per file**. It receives the file and
  endpoint on its environment: `HMUX_UPLOAD_LOCAL_PATH`, `HMUX_UPLOAD_REMOTE_PATH`
  (the `/tmp/hmux-drop-<uuid>.<ext>` path hmux picked;
  see below), `HMUX_UPLOAD_DESTINATION`,
  `HMUX_UPLOAD_PORT`, `HMUX_UPLOAD_IDENTITY_FILE`, and `HMUX_UPLOAD_SSH_OPTIONS`
  (newline-separated; the last three are unset when the session has none). The
  rest of the environment is inherited, so a one-liner resolves tools on `PATH`.
- `enabled`: set to `false` to keep a rule in the list but skip it. Defaults to
  `true`.

**First matching enabled rule wins.** If no rule matches, the built-in `scp` runs
unchanged, so other hosts are untouched.

### The custom command owns the upload

`HMUX_UPLOAD_REMOTE_PATH` is an absolute path under `/tmp`, with a random name
and a lowercased file extension. Its parent already exists, so a command can
copy to it without creating a session directory:

```sh
scp "$HMUX_UPLOAD_LOCAL_PATH" "$HMUX_UPLOAD_DESTINATION:$HMUX_UPLOAD_REMOTE_PATH"
```

The example uses your ssh configuration. If the session supplies
`HMUX_UPLOAD_PORT`, `HMUX_UPLOAD_IDENTITY_FILE` or `HMUX_UPLOAD_SSH_OPTIONS`,
the command must pass those settings to its transport as needed.

The command owns file permissions and cleanup. For sensitive files, use a
private destination and set appropriate permissions through your upload tool.
A command that stores the file somewhere else can ignore the suggested path
and print where it put the file. hmux does not open an extra SSH connection
before running the command, so authentication wrappers and non-SSH upload
services can work independently.

The built-in transport uses a private per-session directory under
`~/.cache/hmux/paste`, creates it with mode `0700`, sets uploaded files to `0600`,
and removes old or excess files. These directory and cleanup rules apply to
built-in uploads; custom commands manage their own destinations.

### How the command's output is used

hmux inserts the command's **stdout** at the cursor:

- Non-empty stdout is inserted **verbatim** (with control characters stripped),
  so a rule can emit a remote path, a URL, or any reference — for example a line
  an agent in the terminal will read.
- If the command prints **nothing**, hmux inserts the shell-escaped remote path it
  chose, so the simplest rule just moves the file and behaves like the built-in.
- For a multi-file drop, each file's output is joined with spaces.

The output is **inserted, not executed** — nothing auto-submits, and you review it
before pressing Enter. Because it is inserted verbatim (rather than shell-escaped
like the built-in path), a rule's stdout should be trusted: it can land at a shell
prompt. A non-zero exit, a timeout, or cancelling from the transfer indicator
inserts nothing — exactly like an `scp` failure.

## `automation.workspaceAutoNaming`

Opt-in AI auto-naming of workspaces and tabs from agent conversation content. When enabled, hmux summarizes supported agent sessions into short sidebar and tab names using each agent's own binary, and refreshes them as the conversation topic shifts. See [workspace-auto-naming.md](workspace-auto-naming.md) for the supported adapter list and full behavior.

```json
{
  "automation": {
    "workspaceAutoNaming": true
  }
}
```

Default: `false`. Manual renames (sidebar, command palette, CLI, or `/rename`) always win: a workspace or tab you renamed yourself is never auto-named again until you clear its custom name. Enable it from **Settings > Automation > Workspace Auto-Naming**.

## `automation.agentAutoResume`

Sends `continue` to a hmux-launched agent whose turn ended on a retryable upstream error, such as the model being at capacity, an overloaded API, or a lost connection. Retries back off between attempts. When the error says when capacity returns, as Subrouter's `retry after <N>s` does once every pooled account is exhausted, the resume waits at least until then plus 30 seconds to 3 minutes, so machines sharing one pool do not all resume at once. The sidebar's **Auto-resumed ×N** marker clears once the agent finishes a turn on its own. A turn that ended waiting on a human (a question, a permission prompt, or a normal finish) is never resumed.

```json
{
  "automation": {
    "agentAutoResume": false
  }
}
```

Default: `true`. Toggle it from **Settings > Automation > Auto-Resume Agents After Errors** or the command palette.

## `agentMessages.enabled`

The app-wide switch for `hmux agent message`. When `false`, sends fail with "Agent messages are turned off (agentMessages.enabled is false).", nothing is stored, and messages already queued are marked `failed` instead of being delivered. Turning it back on does not resend them.

```json
{
  "agentMessages": {
    "enabled": false
  }
}
```

Default: `true`. Toggle it from **Settings > Automation > Agent Messages**. To turn messages off for one agent or workspace instead, see [Turning messages off](agent-messages.md#turning-messages-off).

## `chief`

Settings for Chief, the Home agent.

| Key | Values | Default | Description |
|---|---|---|---|
| `chief.enabled` | `true`, `false` | `true` | Show the Home row and Chief entry points. When `false`, the Home row, the **Open Chief** shortcut, the **View > Chief** menu item, and the Chief command palette entries are hidden. |
| `chief.harness` | `claude`, `codex` | `claude` | The agent harness Chief runs on: Claude Code or Codex. |
| `chief.model` | string | `""` | The model passed to the harness. Leave empty to use the harness default. |
| `chief.effort` | string | `""` | The reasoning effort passed to the harness, such as `low`, `medium`, or `high`. Leave empty to use the harness default. |

```json
{
  "chief": {
    "enabled": true,
    "harness": "codex",
    "model": "",
    "effort": "high"
  }
}
```

Change these from **Settings > Automation > Chief** too. Open Chief with `⌘⇧C` (`shortcuts.bindings.openChief`).

## `diffViewer.defaultLayout`

Controls the initial layout for newly opened diff viewers.

Values: `unified`, `split`.

Default: `unified`.

```json
{
  "diffViewer": {
    "defaultLayout": "unified"
  }
}
```

The toolbar layout toggle persists the last user choice for future generated diff viewers. Passing `hmux diff --layout split` or `hmux diff --layout unified` overrides both the saved toolbar choice and this default for that invocation.

## `sidebar.beta.workspaceTodos.checklistStyle`

Workspace todos are always available. Status is inferred from live signals (agent needs input / agent running / open PR / merged PRs / dirty tree) and can be pinned manually from the glyph's status popover, the row's context menu (Status submenu, Mark as Done), the command palette, or `hmux workspace status set <lane|auto>`; checklists are managed from the row, the workspace todo pane (`hmux todo open`), `hmux todo ...`, or by agents over the control socket.

`checklistStyle` picks how a row's checklist opens from its summary line: `popover` (default) anchors a checklist popover to the summary line; `inline` expands the items under the row like round one.

```json
{
  "sidebar": {
    "beta": {
      "workspaceTodos": {
        "checklistStyle": "popover"
      }
    }
  }
}
```

Default: `enabled: false`. The setting turns on automatically the first time a status or checklist mutation succeeds from any entrypoint.

Three keyboard shortcuts drive the todo state, all editable in **Settings > Keyboard Shortcuts** or `shortcuts.bindings`:

- `markWorkspaceDone` (default `cmd+;`) pins the selected workspace's status to done.
- `cycleWorkspaceStatus` (default `cmd+shift+;`) advances the status one lane forward (todo → working → needs-attention → review → done → todo).
- `toggleChecklistItemComplete` (default `cmd+return`) toggles the highlighted checklist item in the focused todo pane or checklist popover.

hmux also posts a notification when a workspace's status first reaches done, and when its checklist first becomes fully complete, so you can watch agent progress without keeping the pane open.

## `agents.launchers`

hmux resolves resume commands for the wrapper launchers it owns (`hmux claude-teams`, `hmux codex-teams`, `hmux omo`, …). A launcher hmux does not own is invisible to that resolution: a multi-account router such as [`teamclaude`](https://www.npmjs.com/package/@karpeleslab/teamclaude), an LLM-gateway front end, or any `<wrapper> run -- <agent argv>` shim execs the real agent as a child, so the capture records the inner `claude` and restore replays a bare `claude --resume <id>`. The wrapper is dropped, and whatever it provided — account fallback, quota spreading, request logging — is gone from the restored pane.

Declare the wrapper here and hmux re-supplies it whenever that session resumes.

```json
{
  "agents": {
    "launchers": [
      {
        "id": "teamclaude",
        "kinds": ["claude"],
        "detect": { "argvExecutables": ["teamclaude"] },
        "resumeArgvPrefix": ["teamclaude", "run", "--auto-fallback", "--"]
      }
    ]
  }
}
```

- `id`: stable identifier recorded on the launch capture. Letters, numbers, dots, underscores, and hyphens.
- `kinds` (or `kind` for a single value, never both): built-in agent kinds the launcher wraps, e.g. `["claude"]`. Omit the key to match every kind — an empty array is treated as a mistake, not as "every kind".
- `detect.argvExecutables`: executable names or paths that identify the launcher. A match requires the **executable** of an ancestor process — or its last path component — to equal an entry exactly, so `claude --add-dir ~/src/teamclaude-notes` never matches. Env prefixes, package runners, and interpreters are followed, up to two levels, so all of these are identified as `teamclaude`: `teamclaude run`, `node /usr/local/bin/teamclaude run`, `env VAR=1 VAR2=2 teamclaude run`, `npx --yes teamclaude run`. Only options whose shape hmux knows are skipped, and anything else ends the search rather than being guessed at — a runner option that takes a value (`npx --package <pkg> wrapper`) would otherwise make the value look like the launcher. An interpreter's own options decide what its program even is (`-e`/`-c` supply it inline, `-m` names a module, `-` reads it from stdin), so the search stops at the first option after an interpreter. In short: a wrapper is recognized in its plain forms (`wrapper run`, `node /path/to/wrapper run`, `env VAR=1 wrapper run`, `npx --yes wrapper run`), and a more exotic invocation simply resumes unwrapped. Detection walks the agent's ancestors at capture time, nearest first, and stops after 8 levels.
- `resumeArgvPrefix`: argv words placed in front of the agent's own resume argv. hmux keeps every option it would have passed to the agent directly, so the wrapper never has to restate them.
- `includesAgentExecutable`: keep the agent's `argv[0]` after the prefix. Default `false`, which suits wrappers that re-exec their own agent binary after a `--` separator; set it to `true` for `env`-style wrappers that take a full command.

Behavior notes:

- A project-level `hmux.json` (or `.hmux/hmux.json`) overrides a user-level declaration with the same `id`. The project file is resolved from the agent session's directory, not from wherever a CLI process happened to start.
- Only resume is wrapped. Fresh launches already run under the wrapper because you started them there, and `hmux restore <kind> <checkpoint-id>` in direct mode is left untouched.
- Declarations fail closed. A missing detection entry, an empty `resumeArgvPrefix`, a blank `kinds` array, or a value of the wrong type makes that one declaration unusable — the session then resumes exactly as it did before, without the wrapper. The rest of the file still applies.
- Removing a declaration is safe, and has the same effect: the capture keeps the recorded id, but nothing is re-supplied.
- Hooks keep working for the wrapped agent. When the prefix replaces the agent executable, hmux puts its per-surface agent shim first on `PATH` for the restored process, so the wrapper's own `claude` lookup still finds the hook-injecting shim. A wrapper that ignores `PATH` (an absolute path to the real binary, for example) needs the global fallback instead: `hmux hooks setup --agent claude`.
