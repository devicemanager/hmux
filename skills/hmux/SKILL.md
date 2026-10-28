---
name: hmux
description: End-user control of hmux topology and routing (windows, workspaces, panes/surfaces, focus, moves, reorder, identify, trigger flash). Use when automation needs deterministic placement and navigation in a multi-pane hmux layout.
---

# hmux Core Control

Non-browser hmux topology and routing.

- **Window**: top-level macOS hmux window.
- **Workspace**: tab-like group within a window.
- **Pane**: split container in a workspace.
- **Surface**: a tab within a pane (terminal or browser panel).

## Fast start

```bash
hmux identify --json                              # current caller context
hmux list-windows / list-workspaces / list-panes
hmux list-pane-surfaces --pane pane:1
hmux new-workspace
hmux new-split right --surface surface:1
hmux new-split down --command "npm run dev"       # new terminal runs the command in a live shell
hmux move-surface --surface surface:7 --pane pane:2 --focus true
hmux split-off --surface surface:7 right
hmux reorder-surface --surface surface:7 --before surface:3

# workspace context-menu actions (color, description, rename, pin, ...)
hmux workspace-action --action set-color --color Blue
hmux workspace-action --action set-description --description "Ship checklist"

# attention cue
hmux trigger-flash --surface surface:7
```

## Handle model

Output defaults to short refs (`window:N`, `workspace:N`, `pane:N`, `surface:N`). UUIDs are accepted as input; request UUID output only when needed with `--id-format uuids|both`.

## Initial command on new terminals

`new-workspace`, `new-split`, `new-pane`, and `new-surface` accept `--command <text>`. hmux starts the terminal's normal interactive shell and delivers the text plus one Enter at spawn time, so the command runs immediately and the shell stays alive after it exits. No follow-up `send` or `send-key enter` is needed, and the text is passed literally (quoting, `&&`, pipes, and `$VARS` are interpreted by the new shell). The flag is terminal-only: it is rejected with `--type browser|simulator|agent-session`, blank text is ignored, and `new-workspace --layout` ignores it because layout surfaces define their own commands. Details: [references/panes-surfaces.md](references/panes-surfaces.md).

## Settings

hmux-owned settings live in `~/.config/hmux/hmux.json`. `hmux docs settings` prints the docs URL, schema URL, raw GitHub resources, hmux.json paths, and reload command. `hmux settings`, `hmux settings hmux-json`, and `hmux settings shortcuts` open the UI.

`hmux reload-config` reloads both `hmux.json` and `~/.config/ghostty/config`, refreshing terminals in place with no app restart.

Terminal rendering (font, cursor style, theme, scrollback, `background-opacity`, `background-blur`) belongs in Ghostty config, not hmux settings. Everything else (app behavior, sidebar, notifications, browser behavior, automation, workspace colors, hmux-owned shortcuts) is hmux settings. Before editing, copy any existing `hmux.json` to a timestamped `.bak` next to it. Legacy `~/.config/hmux/settings.json` and `~/Library/Application Support/com.hmuxterm.app/settings.json` are read only as fallback for missing keys.

For a completed download, the CLI can inspect the bounded history owned by the
target browser surface without consuming a waiter:

```bash
hmux browser --surface <surface> download list
hmux browser --surface <surface> download list --limit 5 --json
```

Use the browser skill for the full response fields and wait/path compatibility
details.

## Deep-dive references

| Reference | When to Use |
|-----------|-------------|
| [references/handles-and-identify.md](references/handles-and-identify.md) | Handle syntax, self-identify, caller targeting |
| [references/windows-workspaces.md](references/windows-workspaces.md) | Window/workspace lifecycle, reorder/move, and context-menu actions (color, description, rename) |
| [references/panes-surfaces.md](references/panes-surfaces.md) | Splits, surfaces, move/reorder, focus routing |
| [references/trigger-flash-and-health.md](references/trigger-flash-and-health.md) | Flash cue and surface health checks |
| [../hmux-workspace/SKILL.md](../hmux-workspace/SKILL.md) | Current caller workspace rules and non-disruptive automation |
| [../hmux-settings/SKILL.md](../hmux-settings/SKILL.md) | Safe hmux.json settings edits and validation |
| [../hmux-browser/SKILL.md](../hmux-browser/SKILL.md) | Browser automation on surface-backed webviews |
| [../hmux-markdown/SKILL.md](../hmux-markdown/SKILL.md) | Markdown viewer panel with live file watching |
| [../hmux-capture/SKILL.md](../hmux-capture/SKILL.md) | Screenshots and clips of a hmux window for evidence |
