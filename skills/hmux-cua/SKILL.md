---
name: hmux-cua
disable-model-invocation: true
description: "Use only after the user explicitly asks for hmux Computer Use through the hmux-cua skill: drive real macOS apps from a hmux agent session via the bundled engine (accessibility tree + screenshots, click/type/scroll/drag, branded cursor), or explain its user-directed permission setup. Reading or discovering this skill is not consent."
---

# hmux-cua

hmux bundles a local computer-use engine (packaged as `hmux Computer Use` with
the MCP proxy named `hmux-cua`, from a pinned build of
the `manaflow-ai/cmux-cua` fork) and attaches it as an MCP tool server named
`hmux-cua` to every agent session hmux launches (Claude Code, Codex).
The agent can then perceive and operate real macOS apps: read the accessibility
tree, take screenshots, and click / type / scroll / drag.

Everything runs locally through the bundled **hmux Computer Use** helper. The
helper has its own TCC identity, so Accessibility and Screen Recording never
belong to the main hmux app and granting Screen Recording never requires
restarting hmux. Upstream telemetry and update checks are disabled at runtime.

Do not invoke this skill, start its helper, request permissions, or perform a
GUI action when the user is only reading, asking about, quoting, or mentioning
hmux Computer Use. Wait for a direct user request to use hmux Computer Use; missing tools
or permissions are not a reason to begin setup automatically.

## How it attaches

- The `hmux-claude-wrapper` and `hmux-codex-wrapper` inject `hmux-cua` as an
  MCP proxy using `mcp --socket <hmux-owned socket>` plus cursor-branding and
  state-dir env. Codex launches the exact tag-installed helper executable as
  its authenticated approval broker; Claude uses the bundled native-profile
  proxy client. The Codex wrapper additionally passes
  `--codex-computer-use-compat`; the Claude wrapper deliberately does not.
  Attachment availability is not user consent: merely starting an agent or
  discovering this skill is not a request to use it, and it must not open a
  permission window or perform GUI work.
- In Codex sessions launched by hmux, the wrapper disables Codex's native
  `computer_use` provider. When the user says `$hmux-cua`, use only the
  namespaced `hmux-cua` MCP tools below. Never substitute Codex's built-in
  `computer` tool, another CUA connector, or a direct helper launch. If the
  `hmux-cua` tools are absent or unavailable, report that they are unavailable
  and stop; do not silently switch providers.
- `ComputerUseRuntimeService` is the only helper lifecycle owner. It installs
  the nested helper under the tag-scoped
  `~/Library/Application Support/hmux/hmux-cua/helper/<scope>/` directory
  and launches that explicit app URL through LaunchServices.
- The native daemon uses the tag-scoped
  `/tmp/hmux-cua-<uid>/<scope>/hmux-cua.sock`; the Codex compatibility daemon uses
  `hmux-cua-codex.sock` beside it. Both fit Darwin's Unix-socket path limit and share
  the tag-scoped hmux Application Support state directory.
- Neither wrapper installs global skills or adds skill directories by default.
  Use the agent's normal skill installer for a persistent user-owned installation.
  Alternatively, `HMUX_COMPUTER_USE_INSTALL_GLOBAL_SKILL=1` requests an app-managed
  global link for that launch (`~/.agents/skills/hmux-cua` for Codex or
  `~/.claude/skills/hmux-cua` for Claude). Export the flag to retain these links
  on future launches; they may also appear outside hmux. Unset or `=0` removes
  only verified app-managed links. Project and user-owned skills take precedence,
  with no competing global install or automatic fallback. Codex 0.153 does not
  discover new paths from `skills.config`; no Claude projection or plugin
  fallback is used. Migration of the canonical and legacy `hmux-computer-use` /
  `codex-cua` links requires an existing hmux bundle ID, known install/build root,
  and root/current-user ownership. Unknown or dangling targets, real skill
  directories, unrelated symlinks, and project paths are preserved.
  `HMUX_CUA_DIAGNOSTICS=1` identifies preserved paths blocking explicit install
  and verified managed links retired by the per-launch policy. Historical
  app-created and manually-created symlinks with identical verified targets
  cannot be distinguished retroactively; recognized app-bundle links are
  treated as hmux-managed, while unknown and dangling links are preserved.
- While Computer Use is enabled, the helper daemon starts quietly at hmux
  startup with its internal permission gate disabled. Starting hmux or an agent
  never requests access or shows onboarding.
- Wrappers are pure forced proxies. They never copy or launch the helper and
  never fall back to in-process computer use. hmux owns the onboarding window
  and opens the permanent macOS permission panes directly; it does not ask the
  helper to raise an intermediate native prompt. The proxy keeps its
  external-flow flag on so the first driving call waits for both helper grants
  before it is forwarded.
- An explicit functional `$hmux-cua` request is the opt-in: if the saved
  Computer Use toggle is off, hmux enables the runtime and opens onboarding
  automatically. The hard kill switch is `HMUX_COMPUTER_USE_MCP_DISABLED=1`
  (or managed policy); turning the Settings toggle off only stops automatic
  helper startup until the next explicit request.
- Attaches only on hmux-launched, live-socket sessions (same authority bar as
  hmux hooks); hooks-disabled and stale-socket sessions do not attach.

## Permissions (one-time, granted to the helper)

Two macOS permissions are required and are owned by **hmux Computer Use**, not
the main hmux app:

- **Accessibility** — inspect and drive app UI (`AXIsProcessTrusted`).
- **Screen Recording** — screenshots / vision (`CGPreflightScreenCaptureAccess`).

When the user has asked for hmux Computer Use through this skill, the first functional tool call from
a current hmux agent session opens setup automatically if setup is required.
Opening setup does not grant access: the user still completes each permission
step. Skill loading, prompt text, MCP discovery, `check_permissions`, hmux
startup, and agent resume never open setup. Settings → hmux Computer Use also opens
setup through **Finish Setup…**, **Grant…**, or **Open System Settings** and shows the two authoritative
permission states; choosing **Grant…** for an ungranted permission opens that
same permission step and its draggable helper-app recovery path. Each **Allow**
action opens the matching permanent System Settings pane in one step and stays
labeled **Allow** until the helper reports the grant; pressing it again simply
reopens the same pane. If macOS has not listed the helper yet, drag or add the
**hmux Computer Use** app tile to the list, then turn it on. hmux reads status
from the helper over its Unix socket, advances beside System Settings to the
next missing permission, and shows completion in place once both are granted.
On macOS Tahoe a third confirmation follows Screen Recording: the system's
direct-capture consent, an alert that says **hmux Computer Use** "is attempting
to bypass the system private window picker". That alert is expected — it comes
from onboarding's host-authenticated capture probe, onboarding explains it in
place, and the user must allow it before setup completes. Never "fix" it by
suppressing the probe; without that consent, agent screenshots on Tahoe fail.
The consent follows the helper's code signature, so every rebuilt (ad-hoc
signed) dev helper can require the direct-capture step again: hmux invalidates
its cached direct-capture-ready flag whenever it replaces the installed helper
build. Helper replacement stays quiet until the next functional Computer Use
request or a deliberate Settings action.
Do not invoke `check_permissions {prompt:true}` or any standalone helper while
this flow is active: that creates the stray native permission dialogs this
onboarding deliberately avoids. The main hmux process never calls a TCC API or
executes the hmux-cua binary.

An unconfigured proxy waits for setup before forwarding its protected call.
If setup is not finished before the bounded wait ends, it returns **“hmux Computer Use onboarding is still in progress. Finish setup in hmux, then retry.”**
Retries do not repeatedly reopen a dismissed setup window. Resume a dismissed
flow with **Finish Setup…** in Settings, then retry the requested tool. Never
attempt to grant consent by calling a setup/status tool.

A TCC prompt naming **Codex Computer Use** (`com.openai.sky.CUAService`) is
not from hmux. The `codex` CLI ships its own computer-use helper; when codex
runs inside a hmux terminal and pokes that helper with an Apple Event, macOS
attributes the request to the responsible parent — the hmux app — so the
dialog reads as hmux asking to control "Codex Computer Use". Nothing in hmux
or the hmux-cua engine references that service; denying the prompt does not affect
hmux computer use.

If actions fail with a permission error, grant Accessibility to hmux Computer
Use. If screenshots come back blank, grant Screen Recording to hmux Computer
Use. The helper daemon refreshes/restarts to pick up the grant while hmux stays
open. Retry the tool call after onboarding reports both grants.

## Using the tools (agent-facing)

hmux already owns the MCP connection's session identity. Do **not** call
`start_session` / `end_session`, and do not pass a custom `session` argument.
The proxy binds every call to the originating hmux surface so the menu-bar
item, cursor, recording cleanup, and background/focus controls stay attached
to the right agent.

### Codex profile

Codex gets the exact ten-tool Computer Use roster, in order:

`list_apps`, `get_app_state`, `click`, `perform_secondary_action`, `set_value`,
`select_text`, `scroll`, `drag`, `press_key`, `type_text`.

Use it like the built-in Computer Use connector:

1. Call `get_app_state` with the app name, full path, or unambiguous bundle id
   before acting. It launches the app if needed and returns the logical-size
   JPEG screenshot plus the compact accessibility tree.
2. Prefer the current snapshot's string `element_index`; use screenshot-local
   x/y coordinates only as fallback.
3. Use xdotool-style key strings such as `super+l` with `press_key`.
4. Operate controls with visible pointer clicks by default: the branded
   cursor gliding to each button and clicking is the product experience, so
   requests like “click 100 + 105” mean literal button-by-button pointer
   interaction on Calculator's buttons. Reserve `type_text` for entering text
   into text fields (search boxes, forms, editors) — not as a shortcut around
   clicking on-screen controls. Only fall back to a single keyboard sequence
   when the user explicitly asks for speed over visibility or a control has no
   clickable element.
5. Actions return a compact dispatch acknowledgement, not a screenshot or
   accessibility tree. After one or more actions, call `get_app_state` before
   deciding what to do next. The returned screenshot/tree is the authoritative
   verification surface, matching the built-in Computer Use connector.
6. Numeric `element_index` values belong only to the state that displayed them.
   Re-snapshot before using an index that may have been renumbered by a layout
   change (Calculator's **All Clear** removes display nodes, for example).
   Multiple coordinate actions against a stable layout may be issued in one
   host turn; do not batch element-index actions across a state-changing step.

Do not expect native hmux extensions such as `get_window_state`, tokens,
`perform_actions`, cursor controls, diagnostics, recordings, or browser/CDP in
this profile. Their absence is required for Codex schema parity.

### Claude/native hmux profile

Perceive, act in logical groups, then verify:

1. `get_window_state` (pid + window_id) returns the accessibility tree **and** a
   screenshot. Ground on both. Prefer element addressing.
2. Act by element: `click` with `element_token` (or `element_index` + pid +
   window_id) is the robust path. Pixel addressing (`x`,`y`) is the fallback.
3. For a stable, already-snapshotted control set, call `perform_actions` once
   with the ordered `click` / `type_text` / `press_key` / other input steps.
   This reuses the existing element-token cache and visible cursor inside the
   persistent proxy instead of paying one model/MCP round trip and AX scan per
   click. Do not put navigation, modal-opening, or layout-changing actions
   before later control references in the same group; re-snapshot immediately
   after any action that can invalidate those controls.
4. Verify the completed group by re-snapshotting and reading the element
   `value` / screenshot — do not assume actions landed (clicks are never
   helper-verified). Operate on-screen controls with visible pointer clicks by
   default — the gliding branded cursor is the product experience. Use
   `type_text` for entering text into text fields, and fall back to a pure
   keyboard sequence only when the user explicitly prefers speed over
   visibility.

Notes:
- In the native profile, use `list_apps` / `launch_app` / `list_windows` to
  find targets;
  `get_window_state` needs a `window_id` from `list_windows`.
- Catalyst apps (e.g. Calculator) can expose an empty AX tree briefly after
  launch and return spurious AX error codes (-25204) even when the action
  landed — re-snapshot and check the result rather than trusting the code.
- Pixel input is obstruction-checked: if another window covers the target
  point hmux-cua refuses with `background_occluded` naming the occluder
  instead of clicking the wrong window. Retry with `delivery_mode:"foreground"`
  or front the target.
- The bundled Codex compatibility profile exposes `delivery_mode` on `click`
  and `drag`. A click can be retried with `delivery_mode:"foreground"`; this
  briefly fronts the snapshotted window, dispatches the click, and restores the
  previous app. The action remains unverified until a fresh state call confirms
  its effect.
- macOS obstruction checks use WindowServer rectangles. System-owned surfaces
  such as the Dock can be reported at a point that is not visible in the app
  screenshot, so `background_occluded` is a safety stop rather than proof that
  the target is visibly covered. Keep the protection and use the foreground
  retry when bringing the target forward is acceptable.
- Background coordinate drags are unavailable on macOS and return
  `background_unavailable`; pass `delivery_mode:"foreground"` with the
  snapshotted target window for a real drag. A report that dragging fails is
  not independently verified by this contract change.

## The branded agent cursor

The agent's pointer shows as the hmux logo gradient (`#12c7f5 → #2d8cff →
#6c5cff`) with a `hmux` label, so it is visually distinct from the user's
cursor. It is configured by env the wrapper injects
(`HMUX_CUA_CURSOR_GRADIENT` / `_BLOOM` / `_LABEL`) and is auto-active while
the helper daemon is driving. It remains visible across normal reasoning gaps
and is removed when the driving session ends or the proxy control connection
closes. Each later action reasserts the cursor directly above the driven
target. If no cursor appears during an action, confirm the MCP config uses the
helper socket, has a stable `HMUX_CUA_DEFAULT_SESSION`, and uses the pinned
  hmux-cua build.

## Finding and focusing the driving session

While an agent is driving, the **hmux Computer Use** menu-bar item projects only
the most recently active live agent session and offers two presentation modes:

- **Focus Computer Use** — bring forward the app the agent is driving and resume
  automatically following new targets.
- **Focus Calling Terminal** — return to the terminal that invoked Computer Use
  and reveal the exact workspace + surface running that agent while automation
  continues in the background.

The helper pins its cursor window directly above the driven target window at
the normal application window level. That keeps the cursor visible on the
target while allowing any app the user places in front of that target to cover
the cursor naturally; presentation mode never promotes it to an always-on-top
layer.

The active target and session ordering come from hmux-cua's per-session state
files under `~/Library/Application Support/hmux/hmux-cua/runtime/<scope>/state/`.

The item hides when there is no live or recent session. Toggle visibility in
Settings → hmux Computer Use.

## Troubleshooting

- **Agent has no computer-use tools** — the session was launched outside hmux,
  the hard kill switch is active, or the wrapper started before the tagged app.
  Start a fresh session inside the tagged hmux app; the first functional
  request enables setup automatically.
- **Clicks do nothing / not permitted** — grant Accessibility to hmux Computer Use.
- **Black/empty screenshots** — grant Screen Recording to hmux Computer Use;
  restart only the helper if its automatic refresh has not completed yet.
- **No menu-bar icon** — needs a live/recent session; check the visibility toggle.
- **Prompts name the main hmux app** — a non-hmux fallback executed the helper
  directly. Stop there and report the failure; the bundled path must use the
  tag-scoped socket with `HMUX_CUA_MCP_FORCE_PROXY=1`.
- **Prompts name HmuxCua** — a stale `/Applications/HmuxCua.app` daemon or a
  standalone helper launch is active. Stop it and reset/remove its TCC entry;
  the bundled path never uses that identity.

## Development

- Engine source: `manaflow-ai/cmux-cua` (`libs/hmux-cua/rust`). hmux consumes
  it via `HMUX_CUA_PINNED_SHA` in `scripts/build-hmux-cua.sh`, which builds,
  lipos, and codesigns the binary plus the nested helper into the app bundle.
- The helper daemon's `HMUX_CUA_EXTERNAL_PERMISSION_FLOW=1` prevents
  agent-supplied `check_permissions {prompt:true}` from bypassing hmux
  onboarding. The wrappers set `HMUX_CUA_MCP_FORCE_PROXY=1` and preserve
  the external-flow contract in the proxy process so protected calls wait for
  hmux's post-verification readiness signal.
  There is no ambient executable override. Both profiles resolve the
  tag-scoped installed helper's `hmux-cua` executable only, through the shared
  `client-policy.sh`; missing ownership fails closed instead of running a
  user-supplied executable.
- If the hmux-owned daemon is unavailable, do **not** invoke `hmux-cua`
  directly through Bash and do not start its default socket. Tell the user to
  open Settings → hmux Computer Use or restart the tagged hmux build, then retry the
  MCP tool after the helper runtime is healthy.
- Never hand-edit `docs/.../hmux-cua/mcp-tools.mdx` in the fork — it is
  generated from the Rust tool descriptions.
- The runtime service, helper lifecycle, capture and daemon admission live in
  `Packages/macOS/HmuxComputerUse/`. hmux-side UX lives in `Sources/App/ComputerUse*.swift`,
  `Packages/macOS/HmuxSettingsUI/.../Sections/ComputerUseSection.swift`, and the
  two wrappers under `Resources/bin/`.
