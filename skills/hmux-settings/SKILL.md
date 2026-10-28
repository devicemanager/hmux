---
name: hmux-settings
description: "View and edit hmux settings in ~/.config/hmux/hmux.json, including terminal, browser, Markdown, diff, notes, HTML, file preview, and sidebar-tool behavior. Use when the user wants to change hmux preferences, set a value by JSON path, validate the file, open it in an editor, or look up which keys hmux recognizes. Triggers on '/hmux-settings', 'change hmux setting', 'customize viewer', 'set <something> in hmux', 'hmux config', 'hmux.json', or 'rebind a hmux shortcut'."
---

# hmux-settings

hmux reads user settings from `~/.config/hmux/hmux.json` (JSONC). A file watcher applies changes on save, no restart. Legacy `~/.config/hmux/settings.json` is read only as a fallback for keys absent from `hmux.json`.

Schema: `https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json`. The helper uses the schema-generated path list in `references/all-keys.md` in both checkouts and installed skills. If that reference is unavailable, it falls back to paths discoverable in `Sources/HmuxSettingsJSONPathSupport.swift`. Settings sections are `app`, `terminal`, `notifications`, `sidebar`, `sidebarAppearance`, `workspaceColors`, `automation`, `agentMessages`, `browser`, `markdown`, `fileEditor`, `fileExplorer`, `diffViewer`, and `shortcuts`. Non-settings sections (`actions`, `ui`, `commands`, `vault`, `rightSidebar`) share the same file.

For a viewer-specific route, read [the viewer matrix](../hmux-customization/references/viewer-types.md). It distinguishes settings-backed knobs from structural configuration and viewer types that do not have a shipped setting yet. Do not invent a `templates.<viewer>` path: the schema is authoritative, and the adjacent templates proposal is not a supported configuration surface until its keys appear in `web/data/hmux.schema.json`.

## Helper script

Use the bundled helper for every read/write. It strips JSONC comments, validates the complete proposed document with `hmux config validate` before writing, and writes atomically unless the change adds a validation issue. Issues the file already had, such as a key from a newer hmux, don't block an unrelated change; run `validate` to see them.

```bash
skills/hmux-settings/scripts/hmux-settings <subcommand>            # from a hmux checkout
~/.codex/skills/hmux-settings/scripts/hmux-settings <subcommand>   # installed Codex skill
```

The rest of this doc assumes it is on `$PATH` as `hmux-settings`; from a checkout, `export PATH="$PWD/skills/hmux-settings/scripts:$PATH"`.

| Command | What it does |
|---|---|
| `hmux-settings path` | Print the config path. |
| `hmux-settings dump` | Print the raw file (preserves comments). |
| `hmux-settings dump --no-comments` | Print the parsed JSON. |
| `hmux-settings get <a.b.c>` | Print value at dotted JSON path. |
| `hmux-settings set <a.b.c> <value>` | Set value. `<value>` is parsed as JSON (`true`, `42`, `"text"`, `[…]`, `{…}`); unquoted plain words are stored as strings. |
| `hmux-settings unset <a.b.c>` | Delete key, reverting to the in-app default. |
| `hmux-settings undo <receipt>` | Restore one path changed by `set`/`unset --receipt`, only if it still holds the value that change installed. |
| `hmux-settings list-supported` | List every settings JSON path the app recognizes. |
| `hmux-settings validate` | Run the same semantic validation as `hmux config validate` (unknown paths, types, enums, bounds, nested constraints, and config scope). |
| `hmux-settings open` | Open `hmux.json` in `$EDITOR`, VS Code, Cursor, or TextEdit. |

`--file <path>` overrides the target file. Scope is inferred from the real global paths and the project config discovered from the current directory; use `--scope global|project` to override that inference for an arbitrary file.

The installed `hmux` CLI covers the common edits without the helper: `hmux config get|set|unset|toggle|cycle <path>` and `hmux config preset <name>` validate against the same schema, keep comments, and write `~/.config/hmux/hmux.json`. They share one write path with `"type": "setting"` and `"type": "settingPreset"` actions, which put the same edits on a tab bar button, shortcut, or Command Palette entry. Use the helper when you need `--preview`, receipts, `undo`, or a file other than the global config. Paths split on every `.`, so a key that itself contains `.` (for example a `workspaceGroups.byCwd` entry for `~/src/app.web`) is refused by these commands with an error saying so; edit that key in the file directly.

## Workflow

1. Look up the key when the user named a setting in plain English:
   ```bash
   hmux-settings list-supported | rg -i 'sidebar.*terminal|terminal.*sidebar'
   ```
2. Set it. JSON literals must be valid JSON.
   ```bash
   hmux-settings set sidebarAppearance.matchTerminalBackground true
   hmux-settings set app.appearance dark
   hmux-settings set shortcuts.bindings.newTab '["ctrl+b","c"]'
   hmux-settings set browser.hostsToOpenInEmbeddedBrowser '["localhost","*.internal.example"]'
   ```
3. Read back and `hmux-settings validate`.
4. Tell the user it auto-reloaded, and that `hmux-settings unset <key>` reverts it.

## Viewer settings

Use the matrix to identify the surface before editing. The shipped settings-backed viewer paths are:

```bash
hmux-settings list-supported | rg '^(browser|markdown|fileEditor|fileExplorer|diffViewer)\.'
```

Examples:

```bash
hmux-settings set markdown.fontSize 16
hmux-settings set fileEditor.wordWrap true
hmux-settings set fileExplorer.doubleClickAction '"preferredEditor"'
hmux-settings set diffViewer.defaultLayout '"split"'
```

Browser profile import, per-page navigation, developer tools, and the current
right-sidebar tab are runtime or UI state; use the browser/sidebar commands or
the relevant Settings pane instead of adding guessed JSON keys. After any
successful edit, run `hmux reload-config` and validate the exact path.

`set` and `unset` print a JSON result such as `{"status": "persisted", "key": "app.appearance", "runtime": "unobserved"}`. It records what reached disk; the running app's reload is not observed. A refusal prints `{"status": "conflict", "code": ...}` on stderr and exits 1 without writing. An `invalid_config` refusal adds `issues`, the path and message of each problem the change would add.

## Reversible changes

Use these when a change may need to be taken back later, for example a preset the user can uninstall:

```bash
hmux-settings set computerUse.showInMenuBar false --preview        # prints the change and a revision; writes nothing
hmux-settings set computerUse.showInMenuBar false \
  --expect-revision <revision> --receipt ~/private/menu-bar-undo.json
hmux-settings undo ~/private/menu-bar-undo.json
```

- `--expect-revision` refuses the write if the file changed since the preview.
- `--receipt` creates a new mode-0600 file and never overwrites one; an existing file returns `receipt_exists`, and a path that can't be created returns `receipt_unwritable`, before anything is written. It holds config values, so keep it private.
- `undo` restores the prior value, or the prior absence, only while the path on the same resolved file still holds the value the receipt installed. If the user or another tool changed it since, `undo` returns `undo_conflict` and leaves the newer choice alone.
- Plain `unset` is an unconditional reset, not an undo.

## Quick reference

- Appearance: `app.appearance` (`"system" | "light" | "dark"`), `app.appIcon`, `app.menuBarOnly`, `app.minimalMode`.
- Sidebar tint: `sidebarAppearance.matchTerminalBackground`, `.tintColor`, `.tintOpacity` (0..1).
- Sidebar details: `sidebar.hideAllDetails`, `.showBranchDirectory`, `.showPullRequests`, `.showPorts`, `.showLog`.
- Notifications: `notifications.dockBadge`, `.sound` (enum including `"none"`, `"custom_file"`), `.customSoundFilePath`, `.hooks` (array).
- Browser: `browser.defaultSearchEngine`, `.theme`, `.defaultZoomLevel`, `.openTerminalLinksInHmuxBrowser`, `.hostsToOpenInEmbeddedBrowser`.
- Automation: `automation.socketControlMode` (`off | hmuxOnly | automation | password | allowAll`), `.portBase`, `.portRange`.
- Shortcuts: `shortcuts.bindings.<actionId>` = `"cmd+b"`, `["ctrl+b","c"]`, `null`, or `""` to unbind. Action ids in [references/shortcut-actions.md](references/shortcut-actions.md).

Full list of settings, defaults, and descriptions: `hmux-settings list-supported` or [references/all-keys.md](references/all-keys.md).

## Rules

- Only edit `hmux.json`. Never `settings.json` unless the user explicitly asks; it is legacy and read only when a key is absent from `hmux.json`.
- Never tell the user to restart hmux. The file watcher reloads on save.
- Always `hmux-settings validate` after a bulk edit. Validation errors include the exact config path and violated constraint.
- Do not blindly overwrite `actions`, `ui`, `commands`, `vault`, or `rightSidebar`; they share the file and hold hand-tuned non-settings config.
- Shortcut action ids must match the schema enum. Look them up before binding.
- Colors are `#RRGGBB`; opacities are `0..1`.
- Translate app-level phrasing ("Settings > Notifications > Dock badge") to the JSON path first; `web/app/[locale]/(landing)/docs/configuration/page.tsx` mirrors the schema 1:1.
