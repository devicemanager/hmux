---
name: hmux-customization
description: "Customize hmux for an end user, including terminal, browser, Markdown, diff, file preview, notes, HTML, and right-sidebar viewers. Use when changing hmux.json actions, custom commands, workspace layouts, plus-button behavior, surface tab bar buttons, Command Palette entries, Dock controls, sidebar and app settings, shortcuts, notifications, browser routing, examples-library presets, or Ghostty-backed terminal preferences."
---

# hmux Customization

Keep the user's config intact, prefer schema-backed edits, and validate before reporting completion.

For content viewers, start with [the viewer customization matrix](references/viewer-types.md).
It maps each viewer to the settings, command, or external file that owns its
knobs, including explicit fallbacks for viewer types whose template settings
have not shipped yet.

## Choose the right surface

| Want to change | Edit |
|---|---|
| App preferences (appearance, sidebar, notifications, browser routing, automation, shortcuts, new-workspace placement) | `~/.config/hmux/hmux.json` via the `hmux-settings` helper |
| Custom actions, workspace layouts/commands, tab bar buttons, plus-button behavior, Command Palette entries, notification hooks | `~/.config/hmux/hmux.json` globally or `.hmux/hmux.json` in the project |
| Dock controls (right-sidebar terminals: logs, test watchers, git TUIs, dev servers, queues, `hmux feed tui --opentui`) | `.hmux/dock.json` or `~/.config/hmux/dock.json`; `hmux docs dock` when available |
| Terminal rendering and terminal keybindings (fonts, themes, cursor style, copy-on-select, shell integration) | Ghostty config, usually `~/.config/ghostty/config` |
| Bring fonts, colors and terminal behavior over from iTerm2, Terminal, Alacritty, Kitty, WezTerm or a Warp theme | `hmux import <terminal> --dry-run` to preview, then `hmux import <terminal>`; writes hmux's own Ghostty config and a generated theme, never `~/.config/ghostty/config` |
| Workspace names, descriptions, colors, read state, sidebar metadata | hmux CLI, see [../hmux-workspace/SKILL.md](../hmux-workspace/SKILL.md) |
| Feed event sources | `hmux hooks setup` |

Viewer-specific JSON settings live in the global `hmux.json`: `browser.*`,
`markdown.*`, `fileEditor.*`, `fileExplorer.*`, and `diffViewer.*`. Generic file
preview routing also uses `app.openSupportedFilesInHmux` and
`app.openMarkdownInHmuxViewer` plus `app.preferredEditor`. Right-sidebar tools
are structural state and Dock configuration, not a `templates.rightSidebarTool`
object.

Project-local `.hmux/hmux.json` and `.hmux/dock.json` let worktree, SSH, review, dev, CI, and docs patterns travel with the repo; project actions and commands override global entries with the same ID or name. Global app preferences do not belong there.

If a request can be handled by Ghostty config, say so and use Ghostty config instead of inventing hmux UI settings.

Key surfaces in `hmux.json`: `actions` (reusable, can appear in Cmd+Shift+P, surface tab bars, shortcuts, and the plus-button right-click menu; `type: "text"` pastes a snippet into the focused terminal and does not submit it unless `submit: true`), `ui.newWorkspace.action` (replaces the plus-button click) and `ui.newWorkspace.contextMenu` (right-click menu; `ui.newWorkspace.rightClick` is an accepted alias but new examples use `contextMenu`), `ui.surfaceTabBar.buttons` (replaces default tab bar buttons; include built-ins like `hmux.newTerminal`, `hmux.newBrowser`, `hmux.splitRight`, `hmux.splitDown` only when they should stay visible; copy built-ins `hmux.copyWorkingDirectory`, `hmux.copyProjectRoot`, and `hmux.copyScreen` also work here and in `actions`), and `commands` (workspace definitions with split layouts).

## Workflow

1. Inspect existing config.

   ```bash
   test -f ~/.config/hmux/hmux.json && sed -n '1,220p' ~/.config/hmux/hmux.json
   test -f .hmux/hmux.json && sed -n '1,220p' .hmux/hmux.json
   ```

2. Pick global or project-local scope. Default to project-local for repo-specific commands, global for app preferences. Ask only when the choice changes behavior meaningfully.
3. Back up the target file when it already exists (applicable path only, no backup for a missing file).

   ```bash
   stamp="$(date +%Y%m%d-%H%M%S)"
   test -f ~/.config/hmux/hmux.json && cp -p ~/.config/hmux/hmux.json ~/.config/hmux/hmux.json."$stamp".bak
   test -f .hmux/hmux.json && cp -p .hmux/hmux.json .hmux/hmux.json."$stamp".bak
   ```

4. For app settings and hmux-owned shortcuts, use the settings helper (`~/.codex/skills/...` if the user installed with `skills.sh`).

   ```bash
   ~/.agents/skills/hmux-settings/scripts/hmux-settings list-supported
   ~/.agents/skills/hmux-settings/scripts/hmux-settings set browser.openTerminalLinksInHmuxBrowser true
   ~/.agents/skills/hmux-settings/scripts/hmux-settings validate
   ```

5. For actions, UI wiring, workspace layouts, notification hooks, and Dock controls, edit the JSONC by hand and preserve unrelated sections (`vault`, `rightSidebar`, `commands`, `actions`, `ui`, `notifications`).
6. `hmux reload-config`.
7. Verify the configured entrypoint exists: read back the shortcut binding, or confirm the action ID and where it should appear.

For viewer changes, verify the exact path or command state from the matrix. If
the requested viewer or knob is absent from the schema, explain that it is not
supported yet instead of writing an unknown key. The `templates.<viewer>`
surface proposed for future notes/Markdown/diff customization is not available
until the schema and runtime implement it.

## Example: Command Palette action

Appears in Cmd+Shift+P unless `palette` is false.

```json
{
  "actions": {
    "codex-new-tab": {
      "type": "agent",
      "agent": "codex",
      "title": "Codex",
      "subtitle": "Start Codex in this workspace",
      "target": "newTabInCurrentPane",
      "palette": true
    }
  }
}
```

Before choosing a preset, template, starter config, or known workflow pattern, run `hmux docs workflows --json`. Its catalog describes the shipped examples, what each creates, task-fit cues, requirements, adaptation points, and the saved-layout lifecycle. After choosing an example, open [references/examples.md](references/examples.md) for that example's concrete JSON recipe.

## Validation

- App settings: `hmux-settings validate`.
- Keep valid JSONC, no duplicate keys.
- Parse `.hmux/dock.json` or `~/.config/hmux/dock.json` with a JSON parser before reporting completion.
- `hmux reload-config` when the CLI is available.
- Confirm the exact user-facing result: action title, shortcut, plus-button behavior, context-menu entry, or tab bar placement.

## Rules

- Do not overwrite a whole top-level config section unless you own the full section.
- Do not store secrets in actions, commands, or prompts. Use environment variables or the user's secret manager.
- Do not use sleeps or timing workarounds in generated commands.
- Do not add a hmux setting for behavior Ghostty already owns.
- Keep labels short enough for menus, buttons, and the Command Palette.
