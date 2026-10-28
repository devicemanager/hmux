# Windows and Workspaces

```bash
# inspect
hmux list-windows
hmux current-window
hmux list-workspaces
hmux current-workspace

# lifecycle
hmux new-window
hmux focus-window --window window:2
hmux close-window --window window:2
hmux new-workspace
hmux select-workspace --workspace workspace:4
hmux close-workspace --workspace workspace:4

# reorder and move
hmux reorder-workspace --workspace workspace:4 --before workspace:2
hmux move-workspace-to-window --workspace workspace:4 --window window:1
```

## Context-Menu Actions

`hmux workspace-action` runs the workspace right-click actions (color, description, rename, pin, read state, ordering). Defaults to the caller's workspace; override with `--workspace <id|ref|index>`.

```bash
hmux workspace-action --action set-color --color Blue      # name or #RRGGBB hex
hmux workspace-action --action set-description --description "Ship checklist"
hmux workspace-action --action rename --title "infra"
hmux workspace-action --action pin
hmux workspace-action --action clear-color
```

Other actions: `unpin`, `clear-name`, `clear-description`, `mark-read`/`mark-unread`, `move-up`/`move-down`/`move-top`, `close-others`/`close-above`/`close-below`. Named colors: Red, Crimson, Orange, Amber, Olive, Green, Teal, Aqua, Blue, Navy, Indigo, Purple, Magenta, Rose, Brown, Charcoal. `set-color` tints a single workspace (stored as workspace state); the `workspaceColors` block in `hmux.json` defines the shared palette and selection/badge colors, not per-workspace assignments.
