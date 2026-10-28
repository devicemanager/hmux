# Directory Actions Dogfood

This tree is for dogfooding per-directory `hmux.json` resolution.

Use a terminal pane in hmux and `cd` into these directories:

- `dogfood/directory-actions/alpha`
- `dogfood/directory-actions/alpha/nested`
- `dogfood/directory-actions/legacy`
- `dogfood/directory-actions/legacy/prefer-dot-hmux`
- `dogfood/directory-actions/many-tab-actions`

What each one demonstrates:

- `alpha`
  - Inherits the ancestor `./.hmux/hmux.json`
  - Shows ancestor lookup from the active pane cwd
- `alpha/nested`
  - Has its own `./.hmux/hmux.json`
  - Overrides `hmux.newTerminal`
  - Replaces the surface tab bar button list
  - Still inherits parent actions into Command Palette
- `legacy`
  - Uses fallback `./hmux.json`
  - Demonstrates backward-compatible local config loading
- `legacy/prefer-dot-hmux`
  - Contains both `./hmux.json` and `./.hmux/hmux.json`
  - The `./.hmux/hmux.json` file should win
- `many-tab-actions`
  - Defines 24 custom actions plus the 4 built-ins
  - Replaces the surface tab bar button list to stress wide action rows

General expectations:

- Image-backed project-local icons start as a lock until that exact action is trusted.
- Emoji-backed project-local actions show their emoji immediately, but still prompt on first run.
- Running a trusted action opens a new terminal tab in the current pane and sends the configured shell input.
- Command Palette should update as the active pane cwd changes.
