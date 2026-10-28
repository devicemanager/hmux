# hmux Workspace Command Reference

Use these commands from a hmux terminal. Most commands infer the caller workspace from `HMUX_WORKSPACE_ID`, but explicit flags are safer for automation.

## Context

```bash
hmux identify --json
hmux --json --id-format both identify   # stable UUIDs plus human refs, for logs and handoffs
hmux current-workspace --json
hmux capabilities --json
hmux ping
```

## Windows and Workspaces

```bash
hmux list-windows
hmux current-window
hmux new-window
hmux focus-window --window window:2
hmux close-window --window window:2

hmux list-workspaces
hmux list-workspaces --json
hmux new-workspace --name "task" --cwd "$PWD"
hmux new-workspace --command "npm run dev"
hmux new-workspace --layout '{"root":{"type":"terminal"}}'
hmux current-workspace
hmux select-workspace --workspace workspace:2
hmux rename-workspace --workspace workspace:2 -- "new name"
hmux close-workspace --workspace workspace:2
hmux reorder-workspace --workspace workspace:4 --before workspace:2
hmux move-workspace-to-window --workspace workspace:4 --window window:1
```

## Panes and Surfaces

```bash
hmux list-panes --workspace "$HMUX_WORKSPACE_ID"
hmux list-pane-surfaces --workspace "$HMUX_WORKSPACE_ID" --pane pane:1
hmux list-panels --workspace "$HMUX_WORKSPACE_ID"
hmux tree --workspace "$HMUX_WORKSPACE_ID"

hmux new-split right --workspace "$HMUX_WORKSPACE_ID"
hmux new-split down --workspace "$HMUX_WORKSPACE_ID" --surface "$HMUX_SURFACE_ID"
hmux new-split down --workspace "$HMUX_WORKSPACE_ID" --command "npm run dev"
hmux new-pane --workspace "$HMUX_WORKSPACE_ID" --type terminal --direction right
hmux new-pane --workspace "$HMUX_WORKSPACE_ID" --type terminal --direction right --command "tail -f logs/dev.log"
hmux new-pane --workspace "$HMUX_WORKSPACE_ID" --type browser --url http://localhost:3000
hmux new-surface --workspace "$HMUX_WORKSPACE_ID" --type terminal --pane pane:1
hmux new-surface --workspace "$HMUX_WORKSPACE_ID" --type terminal --pane pane:1 --working-directory "$PWD" --command "npm test"
hmux new-surface --workspace "$HMUX_WORKSPACE_ID" --type browser --pane pane:1 --url http://localhost:3000

hmux focus-pane --workspace "$HMUX_WORKSPACE_ID" --pane pane:2
hmux focus-panel --workspace "$HMUX_WORKSPACE_ID" --panel surface:3
hmux close-surface --workspace "$HMUX_WORKSPACE_ID" --surface surface:3
hmux move-surface --surface surface:7 --pane pane:2 --focus true
hmux reorder-surface --surface surface:7 --before surface:3
hmux move-tab-to-new-workspace --surface surface:7 --title "browser"
```

`--command <text>` (also on `new-workspace`) types the text plus one Enter into the new terminal's interactive shell at spawn time, so no follow-up `send` or `send-key enter` is needed and the shell stays alive after the command exits. It is terminal-only (`--type browser|simulator|agent-session` rejects it), blank text is ignored, and `new-workspace --layout` ignores it.

## Input

```bash
hmux send "echo hello\n"
hmux send-key enter
hmux send --surface "$HMUX_SURFACE_ID" "git status\n"
hmux send-key --surface "$HMUX_SURFACE_ID" enter
hmux read-screen --surface "$HMUX_SURFACE_ID"
```

## Sidebar Metadata

```bash
hmux set-status build "running" --workspace "$HMUX_WORKSPACE_ID" --icon hammer --color "#ff9500"
hmux clear-status build --workspace "$HMUX_WORKSPACE_ID"
hmux list-status --workspace "$HMUX_WORKSPACE_ID"
hmux set-progress 0.5 --workspace "$HMUX_WORKSPACE_ID" --label "Building"
hmux clear-progress --workspace "$HMUX_WORKSPACE_ID"
hmux log --workspace "$HMUX_WORKSPACE_ID" --level info -- "Build started"
hmux list-log --workspace "$HMUX_WORKSPACE_ID" --limit 20
hmux clear-log --workspace "$HMUX_WORKSPACE_ID"
hmux sidebar-state --workspace "$HMUX_WORKSPACE_ID" --json
```

## Notifications and Attention

```bash
notification_id="$(hmux notify --title "Done" --body "Task complete" --id-format uuids | awk '$1 == "OK" {print $2}')"
hmux dismiss-notification --id "$notification_id"
hmux notify --clear
hmux list-notifications --json
hmux clear-notifications --workspace "$HMUX_WORKSPACE_ID" --surface "$HMUX_SURFACE_ID"
hmux trigger-flash --workspace "$HMUX_WORKSPACE_ID" --surface "$HMUX_SURFACE_ID"
hmux surface-health --workspace "$HMUX_WORKSPACE_ID" --json
```

## Config and Docs

```bash
hmux docs api
hmux docs browser
hmux docs settings
hmux settings path
hmux settings hmux-json
hmux settings shortcuts
hmux reload-config
```
