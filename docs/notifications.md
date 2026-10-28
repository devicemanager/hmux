# Notifications

hmux provides a notification panel for AI agents like Claude Code, Codex, and OpenCode. Notifications appear in a dedicated panel and trigger macOS system notifications.

> For inline permission / plan / question approvals directly from the sidebar (Vibe Island-style), see **[Feed](feed.md)**. `hmux hooks setup` installs the Feed bridge alongside the notification hooks covered below.

## Quick Start

```bash
# Send a notification (if hmux is available)
command -v hmux &>/dev/null && hmux notify --title "Done" --body "Task complete"

# With fallback to macOS notifications
command -v hmux &>/dev/null && hmux notify --title "Done" --body "Task complete" || osascript -e 'display notification "Task complete" with title "Done"'
```

## Detection

Check if `hmux` CLI is available before using it:

```bash
# Shell
if command -v hmux &>/dev/null; then
    hmux notify --title "Hello"
fi

# One-liner with fallback
command -v hmux &>/dev/null && hmux notify --title "Hello" || osascript -e 'display notification "" with title "Hello"'
```

```python
# Python
import shutil
import subprocess

def notify(title: str, body: str = ""):
    if shutil.which("hmux"):
        subprocess.run(["hmux", "notify", "--title", title, "--body", body])
    else:
        # Fallback to macOS
        subprocess.run(["osascript", "-e", f'display notification "{body}" with title "{title}"'])
```

## CLI Usage

```bash
# Simple notification
hmux notify --title "Build Complete"

# With subtitle and body
hmux notify --title "Claude Code" --subtitle "Permission" --body "Approval needed"

# Post to the panel only: record the entry in the Notifications panel, sidebar
# badge and pane ring without a native banner, for a caller that shows its own
hmux notify --title "Done" --desktop false

# Notify a specific workspace/surface
hmux notify --title "Done" --workspace workspace:1 --surface surface:1

# Compatibility form for older scripts
hmux notify --title "Done" --tab 0 --panel 1

# Capture the returned id and dismiss exactly that notification
notification_id="$(hmux notify --title "Done" --body "Task complete" --id-format uuids | awk '$1 == "OK" {print $2}')"
hmux dismiss-notification --id "$notification_id"

# Clear notifications for the posting surface (same caller resolution as notify)
hmux notify --clear

# Clear a workspace or surface in a specific window
hmux clear-notifications --window window:1 --workspace workspace:1 --surface surface:1
```

## Notifications from hmux Cloud machines

`hmux notify` also works inside a hmux Cloud machine, so agent hooks configured there reach
your Mac. The in-machine `hmux` posts the notification into the machine's own hmux-tui
session (`notification create`, tagged with the terminal it ran in); the Mac reads it off the
machine's event stream it already follows and shows it on the pane that displays that
terminal — or, when no pane shows the terminal (a detached `hmux vm agent` run, a pane you
closed), as a workspace-level notification wherever you are looking at that machine. Nothing
of the machine is on screen: it is dropped.

Inside a machine:

- `--title`, `--body`, and `--level info|warning|error` are honored; `--subtitle` is folded
  into the body (hmux-tui has no subtitle field) and the machine's name becomes the subtitle
  on the Mac.
- `--workspace`, `--surface`, `--window`, `--tab`, `--panel`, and `--reply` are ignored, and
  `--desktop` is validated as `true|false` (except with `--clear`) but otherwise ignored: the
  Mac decides where a machine's notification lands and how it is delivered, and a machine
  never sees a Mac workspace, surface, or socket.
- Text is treated as untrusted: escape sequences, control characters, and bidi/invisible
  characters are stripped, titles are capped at 128 bytes and bodies at 1 KiB, and each
  machine gets a burst of 5 notifications refilling at 1 per second (identical text within
  5 seconds is collapsed).
- A machine's notification shows a banner, sound, sidebar unread marker, and phone
  forwarding, and runs your **global** `~/.config/hmux/hmux.json` hooks and
  `notifications.command` with `HMUX_NOTIFICATION_ORIGIN=cloud-vm:<machine>`. It never gets a
  reply affordance, a click action, agent context, or project `hmux.json` hooks from a local
  directory.

## Notifications from your other Macs

`hmux notify` in a terminal on another Mac under **My Devices** also reaches this Mac while
the link to that Mac is up. This Mac reads the other Mac's notification feed and shows each
unread notification on the pane that mirrors that terminal, or on the local workspace that
shows the terminal's remote workspace. A notification whose terminal and remote workspace are
both not shown here gets no local notification. Reading or dismissing the notification here marks it read on the other Mac.

The same untrusted-text clamps and admission budget as Cloud machines apply, and hooks see
`HMUX_NOTIFICATION_ORIGIN=device-mac:<device>`. Notifications that the other Mac itself got
from a Cloud machine or a third Mac are not relayed, so nothing shows twice or loops.

## Navigation

Use `Cmd+Shift+U` to jump to the latest unread notification. Use `Ctrl+Cmd+U` to mark the current item as oldest unread and jump to the next latest unread. Both shortcuts are configurable in Settings > Keyboard Shortcuts and in `~/.config/hmux/hmux.json`.

Focusing a pane marks that pane's notifications read. A notification posted without a surface belongs to the workspace instead of to a pane (hmux's own memory-pressure warning is one), so switching to the workspace marks the workspace's own notifications read. The other panes in that workspace keep their notifications and any manual or restored unread markers. "Mark Workspace as Read" in the workspace context menu still clears everything in the workspace at once.

## Native banner lifetime and notification history

hmux keeps its notification record and unread state until you open, mark, or
dismiss it (subject to the existing focused-surface dismissal policy). The
native macOS presentation is separate: macOS controls how long a **Banner** is
visible and may remove it after a few seconds. hmux cannot extend that native
Banner lifetime. To keep the system alert visible until you dismiss it, open
**System Settings → Notifications → hmux** and choose **Alert** instead of
**Banner**. The hmux notification panel remains the durable place to review
notifications regardless of that macOS presentation choice.

## Suppress only the focused surface

By default hmux withdraws a delivered banner when its workspace becomes visible/active, which can retract a banner for a non-focused surface (e.g. a second agent in the same visible workspace) before you notice it. Set the opt-in flag below to `true` so the auto-withdraw fires **only** for the exact focused surface — matching the delivery gate. A banner for a non-focused surface then stays up until you focus that surface (or click/dismiss it). Workspace-visible-but-not-focused surfaces and surfaces in non-visible workspaces keep their banners; explicit "mark workspace read" and clicking/typing still clear notifications as before.

```jsonc
{
  "notifications": {
    // Default: false (legacy workspace-visibility withdraw).
    // Set to true to auto-withdraw only the exact focused surface.
    "suppressOnlyFocusedSurface": true
  }
}
```

## Suppress banners while hmux is focused

By default hmux skips the desktop banner only when the notification is for the pane you are looking at. A notification for another workspace or pane still shows a banner even while hmux is the active app. Set the opt-in flag below to `true` to skip the desktop banner for every notification while hmux is the active app. Notifications that arrive after you switch to another app show banners again. Notifications still land in the sidebar with their unread state, the notification sound and custom command still run, and phone forwarding keeps its usual focused-pane rule, since hmux can be frontmost while you are away from the Mac.

```jsonc
{
  "notifications": {
    // Default: false (only the focused pane skips its banner).
    // Set to true to skip banners for every notification while hmux is focused.
    "suppressWhenAppFocused": true
  }
}
```

## Notification Hooks

`hmux.json` can define composable hooks that receive every notification policy as JSON on stdin and return updated JSON on stdout. Hooks are off by default; hmux only runs them when `notifications.hooks` contains at least one enabled hook. Hooks can filter native banners, sidebar history, sounds, custom commands, workspace reordering, and pane flashes.

```json
{
  "notifications": {
    "hooks": [
      {
        "id": "agent-filter",
        "command": "sed 's/\"desktop\":true/\"desktop\":false/'",
        "timeoutSeconds": 20
      }
    ]
  }
}
```

Hook input and output use this shape:

```json
{
  "version": 1,
  "notification": {
    "workspaceId": "3B3F0D83-...",
    "surfaceId": "7E9C1A02-...",
    "title": "Codex",
    "subtitle": "Waiting",
    "body": "Agent needs input"
  },
  "context": {
    "cwd": "/path/to/project",
    "configPath": "/path/to/project/.hmux/hmux.json",
    "hookId": "agent-filter",
    "appFocused": false,
    "focusedPanel": false
  },
  "agent": {
    "kind": "claude",
    "category": "turn-complete",
    "pending": false,
    "isSubagent": true
  },
  "origin": {
    "kind": "cloud-vm",
    "value": "cloud-vm:vivid-newt",
    "machine": "vivid-newt"
  },
  "effects": {
    "record": true,
    "markUnread": true,
    "reorderWorkspace": true,
    "desktop": true,
    "sound": true,
    "command": true,
    "paneFlash": true
  }
}
```

Global hooks from `~/.config/hmux/hmux.json` run first. Project hooks from parent directories to the current workspace append after that. When the caller passed `hmux notify --desktop false`, the request carries `effects: {"desktop": false}` (the same shape a hook emits) and the envelope's `effects.desktop` already starts out `false`, so a hook sees the request and can still override it. Project hooks use the same trust prompt as other project `hmux.json` commands before they run. Feed approval banners also pass through these hooks; disabling `desktop` suppresses the native banner while keeping the Feed item available in hmux. Set `"hooksMode": "replace"` in a project `notifications` section to ignore inherited hooks. If any hook fails, times out, or returns invalid JSON, hmux uses the default notification behavior and posts a hook failure alert.

### Agent-event context

Notifications that originate from an agent completion signal (agent hooks installed by `hmux hooks setup`, or hmux's built-in prompt-turn detection) carry an additional read-only `agent` object so hooks can implement their own per-agent notification policy:

| Field | Description |
|----------|-------------|
| `kind` | Stable lowercase agent slug (`claude`, `codex`, `grok`, `antigravity`, …) |
| `category` | `turn-complete`, `needs-permission`, or `idle-reminder` |
| `pending` | `true` when the turn ended with background work still running |
| `isSubagent` | `true` when the event came from a nested subagent session |

The `agent` object is omitted entirely for non-agent notifications (plain `hmux notify`, OSC 9/99/777 escape sequences, notifications from older hmux CLIs), and individual fields are omitted when unknown. Hooks cannot modify it — patches to `agent` in hook output are ignored. The same context is exported to the hook process environment as `HMUX_NOTIFICATION_AGENT_KIND`, `HMUX_NOTIFICATION_AGENT_CATEGORY`, `HMUX_NOTIFICATION_AGENT_PENDING` (`0`/`1`), and `HMUX_NOTIFICATION_AGENT_IS_SUBAGENT` (`0`/`1`); each variable is set only when the corresponding field is present.

### Origin

The `origin` object is present only for notifications whose text came from somewhere other than this Mac: `kind` is `ssh-relay` (a `hmux ssh` host), `cloud-vm` (a hmux Cloud machine, with `machine` set to its id), or `device-mac` (another Mac under My Devices, with `machine` set to its device id), and `value` is the same string the hook process sees in `HMUX_NOTIFICATION_ORIGIN` — `local`, `ssh-relay:<workspace uuid>`, `cloud-vm:<machine>`, or `device-mac:<device>`. Hooks cannot modify it. `notifications.command` receives the same `HMUX_NOTIFICATION_ORIGIN` variable. Treat remote-origin `title`, `subtitle`, and `body` as untrusted text: use them as data (`"$HMUX_NOTIFICATION_BODY"` in quotes), never interpolate them into a command, an `osascript` source string, or an `eval`. A hook that wants to stay quiet for machines can gate on it:

```sh
case "$HMUX_NOTIFICATION_ORIGIN" in
  cloud-vm:*) printf '{"effects":{"sound":false}}' ;;
esac
```

With no hooks configured, notification behavior is exactly hmux's built-in default — configuring a hook is the explicit opt-in that hands the delivery decision to your script. For example, to keep every built-in behavior except the banner/sound/flash for subagent completions:

```json
{
  "notifications": {
    "hooks": [
      {
        "id": "mute-subagent-completions",
        "command": "if [ \"${HMUX_NOTIFICATION_AGENT_IS_SUBAGENT-0}\" = \"1\" ] && [ \"$HMUX_NOTIFICATION_AGENT_CATEGORY\" = \"turn-complete\" ]; then printf '{\"effects\":{\"desktop\":false,\"sound\":false,\"paneFlash\":false}}'; fi"
      }
    ]
  }
}
```

A hook can also route events into an entirely custom notification system: disable every effect (`record`, `desktop`, `sound`, `command`, `paneFlash`, …) and call your own notifier from the hook script using the JSON on stdin. Note that hmux's built-in subagent suppression (`automation.suppressSubagentNotifications`, on by default) drops subagent completion events before they reach hooks; turn it off if your hook should see subagent events and make its own decision.

## Integration Examples

### Claude Code

See the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for hook configuration.

### GitHub Copilot CLI

Copilot CLI supports [hooks](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-hooks-reference) that run shell commands at key lifecycle events. It loads every `*.json` file in `~/.copilot/hooks/`, or `$COPILOT_HOME/hooks/` when `COPILOT_HOME` is set; it does not read hooks from `~/.copilot/config.json`. `hmux hooks setup copilot` writes `hmux.json` into that directory for you. To add your own, create `notify.json` next to it:

```json
{
  "version": 1,
  "hooks": {
    "userPromptSubmitted": [
      {
        "type": "command",
        "bash": "if command -v hmux &>/dev/null; then hmux set-status copilot_cli Running; fi",
        "timeoutSec": 3
      }
    ],
    "agentStop": [
      {
        "type": "command",
        "bash": "if command -v hmux &>/dev/null; then hmux notify --title 'Copilot CLI' --body 'Done'; hmux set-status copilot_cli Idle; else osascript -e 'display notification \"Done\" with title \"Copilot CLI\"'; fi",
        "timeoutSec": 5
      }
    ],
    "errorOccurred": [
      {
        "type": "command",
        "bash": "if command -v hmux &>/dev/null; then hmux notify --title 'Copilot CLI' --subtitle 'Error' --body \"$(cat | jq -r '.errorMessage // \"An error occurred\"' 2>/dev/null | head -c 100)\"; hmux set-status copilot_cli Error; else osascript -e 'display notification \"An error occurred\" with title \"Copilot CLI\"'; fi",
        "timeoutSec": 5
      }
    ],
    "sessionEnd": [
      {
        "type": "command",
        "bash": "if command -v hmux &>/dev/null; then hmux clear-status copilot_cli; fi",
        "timeoutSec": 3
      }
    ]
  }
}
```

Or for repo-level hooks, create `.github/hooks/notify.json`:

```json
{
  "version": 1,
  "hooks": {
    "userPromptSubmitted": [ ... ],
    "agentStop": [ ... ]
  }
}
```

### OpenAI Codex

Add to `~/.codex/config.toml`:

```toml
notify = ["bash", "-c", "command -v hmux &>/dev/null && hmux notify --title Codex --body \"$(echo $1 | jq -r '.\"last-assistant-message\" // \"Turn complete\"' 2>/dev/null | head -c 100)\" || osascript -e 'display notification \"Turn complete\" with title \"Codex\"'", "--"]
```

Or create a simple script `~/.local/bin/codex-notify.sh`:

```bash
#!/bin/bash
MSG=$(echo "$1" | jq -r '."last-assistant-message" // "Turn complete"' 2>/dev/null | head -c 100)
command -v hmux &>/dev/null && hmux notify --title "Codex" --body "$MSG" || osascript -e "display notification \"$MSG\" with title \"Codex\""
```

Then use:
```toml
notify = ["bash", "~/.local/bin/codex-notify.sh"]
```

### OpenCode Plugin

Create `.opencode/plugins/hmux-notify.js`:

```javascript
export const HmuxNotificationPlugin = async ({ $, }) => {
  const notify = async (title, body) => {
    try {
      await $`command -v hmux && hmux notify --title ${title} --body ${body}`;
    } catch {
      await $`osascript -e ${"display notification \"" + body + "\" with title \"" + title + "\""}`;
    }
  };

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await notify("OpenCode", "Session idle");
      }
    },
  };
};
```

## Cloud machines

Notifications from a hmux Cloud machine are owned by the machine. The
hmux-tui daemon inside it posts a durable notification when an agent finishes
a turn, needs approval, asks a question, requests plan review, or reports an
error, and for `hmux-tui notify`. Every attached Mac receives those rows on the
same state feed the Cloud tree uses, so a notification posted while the link
was down arrives on reconnect, and a daemon restart does not lose it.

Inside a machine, `hmux notify` takes the same flags as the local command
(`--title`, `--subtitle`, `--body`, `--clear`, `--surface`, `--workspace`,
`--desktop`, `--json`) and posts to the machine's own ledger, so scripts and hooks written
for a local terminal work unchanged. `--reply` is not available there.

Read state is per client. Each row carries `read_by`, the client ids that
acknowledged it. Reading the notification on this Mac (focusing the pane,
marking it read, dismissing it) sends `notification.ack` under this Mac's
client id. A second Mac attached to the same machine keeps its own unread
state, and the machine's own TUI keeps its shared console marker.

Locally these notifications behave like any other: they light the workspace
and tab, appear in the notifications list and `hmux list-notifications`, post
a system notification when hmux is in the background, and the Cloud tree
shows a dot on the terminal until this Mac reads it. When no pane on this Mac
shows the terminal, the notification lands on the local workspace bound to
the machine; when no local workspace is bound, only the Cloud tree dot shows
and delivery waits for a placement.

## Environment Variables

hmux sets these in child shells:

| Variable | Description |
|----------|-------------|
| `HMUX_SOCKET_PATH` | Path to control socket |
| `HMUX_TAB_ID` | UUID of the current tab |
| `HMUX_PANEL_ID` | UUID of the current panel |

## CLI Commands

```
hmux notify [--title <text>] [--subtitle <text>] [--body <text>] [--reply] [--desktop <true|false>] [--clear] [--workspace <id|ref|index>] [--surface <id|ref|index>] [--window <id|ref|index>]
hmux list-notifications
hmux dismiss-notification (--id <uuid|notification:<uuid>> | --all-read)
hmux mark-notification-read (--id <uuid|notification:<uuid>> | --workspace <id|ref> [--surface <id|ref>] | --all)
hmux open-notification --id <uuid|notification:<uuid>>
hmux jump-to-unread
hmux clear-notifications [--workspace <id|ref|index>] [--surface <id|ref|index>] [--window <id|ref|index>]
hmux set-status <key> <value>
hmux clear-status <key>
hmux ping
```

## Best Practices

1. **Always check availability first** - Use `command -v hmux` before calling
2. **Provide fallbacks** - Use `|| osascript` for macOS fallback
3. **Keep notifications concise** - Title should be brief, use body for details
