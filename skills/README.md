# Find the right HMUX skill

Choose by the task: operating the installed app and changing its implementation
use different instructions. Load the matching `SKILL.md`, then only the reference
needed for the current operation. Installed CLI `--help` owns available commands
and flags; repository instructions own build and test rules.

## Working on the repository

Run repository commands only from a [trusted checkout](../docs/contributor-verification.md#trust-boundary);
even `verify-local.py --help` and `--list` load repository code.

For a local iteration, start with `python3 scripts/verify-local.py --help`.
`--swift-changed` discovers current Swift edits; `--list` exposes focused checks.
See [hmux-testing](hmux-testing/SKILL.md) for the boundary between static checks,
parsing, test compilation, executed tests and runtime evidence.

| Task | Skill |
| --- | --- |
| Setup, tagged builds, project normalization | [hmux-dev-workflow](hmux-dev-workflow/SKILL.md) |
| Tests, verification scope, target wiring | [hmux-testing](hmux-testing/SKILL.md) |
| Which commit broke a test on main, stale test or regression | [hmux-test-bisect](hmux-test-bisect/SKILL.md) |
| Package boundaries, Swift APIs and concurrency | [hmux-architecture](hmux-architecture/SKILL.md) |
| Backend APIs, providers, database and migrations | [hmux-backend](hmux-backend/SKILL.md) |
| Billing implementation, Stripe and entitlements | [hmux-billing](hmux-billing/SKILL.md) |
| Instrumentation and app/runtime implementation bugs | [hmux-debugging](hmux-debugging/SKILL.md) |
| User-facing strings and localization | [hmux-localization](hmux-localization/SKILL.md) |
| CLI/socket implementation, threading and focus | [hmux-socket-policy](hmux-socket-policy/SKILL.md) |
| Shared actions across multiple entry points | [hmux-shared-behavior](hmux-shared-behavior/SKILL.md) |
| Ghostty submodule or GhosttyKit | [hmux-ghostty](hmux-ghostty/SKILL.md) |
| Versions, changelog and release artifacts | [hmux-release](hmux-release/SKILL.md) |
| Adversarial review of agent-written changes | [hmux-review](hmux-review/SKILL.md) |

## Using the installed app

| Task | Skill |
| --- | --- |
| Inspect or change windows, workspaces, panes and surfaces | [hmux](hmux/SKILL.md) |
| Work in the caller's existing workspace without disrupting it | [hmux-workspace](hmux-workspace/SKILL.md) |
| Browser automation | [hmux-browser](hmux-browser/SKILL.md) |
| Operate Cloud machines and their persistent workspaces | [hmux-cloud-vm](hmux-cloud-vm/SKILL.md) |
| Native computer use when requested | [hmux-cua](hmux-cua/SKILL.md) |
| Screenshot or record a hmux window as evidence | [hmux-capture](hmux-capture/SKILL.md) |
| Settings values and validation | [hmux-settings](hmux-settings/SKILL.md) |
| Shortcuts, key bindings and templates | [hmux-keyboard-shortcuts](hmux-keyboard-shortcuts/SKILL.md) |
| Actions, commands and layouts | [hmux-customization](hmux-customization/SKILL.md) |
| Build a custom sidebar | [hmux-custom-sidebar](hmux-custom-sidebar/SKILL.md) |
| Diagnose installed hooks, settings, restore or socket access | [hmux-diagnostics](hmux-diagnostics/SKILL.md) |
| Display a Markdown file in a viewer | [hmux-markdown](hmux-markdown/SKILL.md) |

Start with diagnostics for a user's broken installation; use debugging when
investigating or changing the source implementation. Similarly, Cloud VM operations
belong to `hmux-cloud-vm`, while its service implementation belongs to `hmux-backend`.
