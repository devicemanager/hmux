# Command Reference (hmux Browser)

## Surface contract

Run `hmux browser --help` against the installed binary before relying on exact
syntax. Creation verbs (`open`, `open-split`, `new`) and the explicitly global
browser verbs listed in `SKILL.md` may omit a surface. Every surface-bound
command that reads or mutates an existing browser must include one:

```bash
hmux browser --surface <surface> get url
hmux browser --surface <surface> snapshot --interactive
hmux browser --surface <surface> tab list
hmux browser --surface <surface> click <selector-or-ref>
```

`hmux browser <surface> <verb> ...` is the equivalent positional form. See
[surface-discovery.md](surface-discovery.md) before targeting an existing
authenticated browser or a browser in another workspace.

## Accepted aliases

Use the preferred column in new docs/scripts; every alias still requires the
same explicit surface.

| Purpose | Preferred | Accepted alias |
| --- | --- | --- |
| Read URL | `hmux browser --surface <surface> get url` | `hmux browser --surface <surface> url` or `get-url` |
| Navigate | `hmux browser --surface <surface> goto <url>` | `navigate` |
| Interactive snapshot | `hmux browser --surface <surface> snapshot --interactive` | `-i` |
| Press a key | `hmux browser --surface <surface> press <key>` | `key` |

The upstream `agent-browser` command's implicit page context maps to an
explicit hmux surface. Its interactive snapshot maps to `snapshot
--interactive`; its `open` command maps to `hmux browser open` because creation
returns a new surface.

## Discovery and creation

```bash
hmux identify --json
hmux tree --all --json
hmux browser --surface <surface> identify --json

hmux --json browser open <url> --focus false
hmux --json browser open <url> --workspace <workspace> --window <window> --focus false
hmux --json browser open-split <url> --workspace <workspace> --focus false
```

Creation defaults to the caller's `HMUX_WORKSPACE_ID` when neither
`--workspace` nor `--window` is supplied, and `--focus` defaults to false. An
explicit `--workspace` lets an agent create in another workspace without
selecting it.

## Navigation

```bash
hmux browser --surface <surface> goto <url>
hmux browser --surface <surface> back|forward|reload
hmux browser --surface <surface> get url|title
```

## Snapshot and inspection

```bash
hmux browser --surface <surface> snapshot --interactive
hmux browser --surface <surface> snapshot --interactive --compact --max-depth 3
hmux browser --surface <surface> get text body
hmux browser --surface <surface> get html body
hmux browser --surface <surface> get value "#email"
hmux browser --surface <surface> get attr "#email" --attr placeholder
hmux browser --surface <surface> get count ".row"
hmux browser --surface <surface> get box "#submit"
hmux browser --surface <surface> get styles "#submit" --property color
hmux browser --surface <surface> eval '<js>'
```

## Interaction

```bash
hmux browser --surface <surface> click|dblclick|hover|focus <selector-or-ref>
hmux browser --surface <surface> fill <selector-or-ref> [text]
hmux browser --surface <surface> type <selector-or-ref> <text>
hmux browser --surface <surface> press|key|keydown|keyup [--key <key> | <key>]
hmux browser --surface <surface> select <selector-or-ref> <value>
hmux browser --surface <surface> check|uncheck <selector-or-ref>
hmux browser --surface <surface> scroll [--selector <css>] [--dx <n>] [--dy <n>]
```

Empty `fill` text clears the field. Keyboard names follow Playwright/W3C
conventions (`Enter`, `Tab`, `Escape`, `ArrowLeft`, `Space`). Supported keys
use the native WebKit input path, preserving browser defaults such as
contenteditable caret movement, selection, scrolling, and control activation;
opaque tokens use a page-event compatibility fallback. `Space`, `Spacebar`,
and `space` emit DOM key `" "` with code `"Space"`; use `--key ' '` to pass
the raw DOM key. Use `keydown Shift`/`keyup Shift` (or another supported
modifier) around an arrow press when a page editor should extend a selection;
the modifier state is retained per browser surface.

## Wait

```bash
hmux browser --surface <surface> wait --selector "#ready" --timeout-ms 10000
hmux browser --surface <surface> wait --text "Done" --timeout-ms 10000
hmux browser --surface <surface> wait --url-contains "/dashboard" --timeout-ms 10000
hmux browser --surface <surface> wait --load-state complete --timeout-ms 15000
hmux browser --surface <surface> wait --function "document.readyState === 'complete'" --timeout-ms 10000
```

## Design mode

```bash
hmux browser --surface <surface> design-mode enable|disable|toggle|status --json
```

Design mode lets a user select page elements and copy their DOM, style, URL,
and screenshot context for pasting into an agent. CLI enable/disable never
moves application focus or copies context automatically.

## Session, state, and diagnostics

```bash
hmux browser --surface <surface> cookies get|set|clear ...
hmux browser --surface <surface> cookies clear --url https://app.example.com/
hmux browser --surface <surface> cookies clear --domain app.example.com
hmux browser --surface <surface> cookies clear --all
hmux browser --surface <surface> storage local|session get|set|clear ...
hmux browser --surface <surface> tab list|new|switch|close ...
hmux browser --surface <surface> state save|load <path>
hmux browser --surface <surface> console list|clear
hmux browser --surface <surface> errors list|clear
hmux browser --surface <surface> highlight <selector>
hmux browser --surface <surface> screenshot
hmux browser --surface <surface> download list [--limit <1...25>]
hmux browser --surface <surface> download wait --timeout-ms 10000
```

`download list` returns the newest records for that browser surface without
consuming `download wait` events. JSON records include `download_id`,
`filename`, the actual saved `path` (or `null`), `status`, `bytes` when known,
and `path_exists` when a path is present. The list is capped at 25 records;
`--limit` may request a smaller positive count. Text output marks unavailable
values explicitly.
The legacy positional form treats a bare token as a destination path, so use
the explicit `download wait <path>` or `download --path <path>` spelling when
you want to make that intent unambiguous. `download list` is the only listing
subcommand.

`cookies clear` requires an explicit scope (`--url`, `--domain`, `--name`,
`--path`, another cookie filter, or `--all`). URL scope follows cookie
domain/path, secure, and expiration matching for the requested URL. JSON
responses include the number of removed cookies as `cleared`.

## Agent reliability

Use `--snapshot-after` on mutating actions to get a fresh post-action snapshot.
Re-snapshot after navigation, modal open/close, or major DOM changes. Prefer
short handles in output; use `--id-format both` only when a UUID must be logged
or exported. If the handle is stale, rediscover it; never silently retarget the
focused browser.

## Viewport emulation

```bash
hmux browser --surface <surface> viewport 1280 720
hmux browser --surface <surface> screenshot --out /tmp/desktop.png
hmux browser --surface <surface> viewport reset
```

Dimensions are limited to 1..4096 CSS pixels. hmux changes
`window.innerWidth`/`window.innerHeight` and aspect-fits the page inside the
existing pane; it does not resize the pane, move other surfaces, or change
focus. Screenshot PNG dimensions are exact CSS pixels on Retina and non-Retina
displays.

An unsupported viewport/page-zoom combination leaves the viewport unchanged
and returns `invalid_params` with reason
`viewport_zoom_render_geometry_too_large` plus `maximum_page_zoom`. An attached
browser inspector returns `invalid_state` with reason
`attached_browser_inspector`; close or detach it first. Opening or redocking an
attached inspector while emulation is active resets the viewport to native
sizing.

## Known WKWebView gaps (`not_supported`)

`browser.trace.start|stop`,
`browser.network.route|unroute|requests`, `browser.screencast.start|stop`, and
`browser.input_mouse|input_keyboard|input_touch` are not supported by the
WKWebView engine.

`browser.geolocation.set` (`latitude`, `longitude`, optional `accuracy`, or
`clear: true`) and `browser.offline.set` (`enabled`) work on WebKit. The
override reaches the loaded page's main frame at once and every later
document in all frames (an iframe already loaded keeps its old values until
it reloads, though offline blocks its loads at once). It survives a web
content crash or a hidden tab discard. A popup the page opens shares the
opener's emulation.

See also [snapshot-refs.md](snapshot-refs.md),
[authentication.md](authentication.md), and
[session-management.md](session-management.md).
