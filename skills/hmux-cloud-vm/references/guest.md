# Working inside a Cloud machine

Read this for guest auth, peer access or presentation behavior.

## Guest auth and CodeRouter

Start with `hmux self --json` to identify the current machine, then use
`hmux self peers` to discover the owner's reachable machines. On an older guest
whose help exposes it, `hmux vm ls` is the compatibility inventory fallback.
Both paths read through the VM-bound TLS edge without a Mac account token. Host
lifecycle verbs still run on the Mac; read the guest's `hmux --help` for the
subset its image supports.

Inside a Cloud machine, the guest `hmux` adapter can report route health and run
an agent through the shared CodeRouter without exposing the Mac's Stack session:

```bash
hmux auth status --json
hmux coderouter status --json
hmux coderouter usage
hmux coderouter models
hmux coderouter agent claude "summarize the current checkout"
hmux agent codex "run the tests"
```

These commands describe the machine's daemon, TLS edge, and VM-bound route.
Host account login and upstream credential management remain on the Mac; do not
copy those tokens into a VM. `vm agent` still starts a detached terminal on the
selected machine, while the guest `hmux agent` form runs through CodeRouter.

## The grammar (one spelling per concept)

| Where you are | What you address | Spelling |
|---|---|---|
| Mac | a machine | `hmux vm <verb> <machine> …` — everything about machines lives here |
| Mac | this Mac's own session | the unprefixed local verbs (`hmux send-key`, `hmux new-workspace`, …) |
| inside a machine | **this** machine's session | the same unprefixed local verbs as on a Mac (`hmux send-key`, `hmux terminal send`, `hmux layout apply`, `hmux env set`, `hmux notify`) |
| inside a machine | **another** machine | `hmux vm <verb> <machine> …` — the same grammar as on the Mac |
| inside a machine | the owner's machines | `hmux self peers` (with reachability); legacy fallback `hmux vm ls` when supported |
| inside a machine | myself | `hmux self [peers\|integrations\|owner\|machine] [--json]` (aliases: `hmux whoami`, `hmux reflect [<path>]`) |
| Mac | a machine's identity | `hmux vm self <machine> [<path>] [--json]` — the same reflection payloads through your session |

## Inside a machine: the same verbs, and other machines

Every machine has its own `hmux` (a shim over its hmux-tui daemon). An agent running *in* the machine drives its own session with the Mac spellings — the target defaults to its own terminal (`$HMUX_TUI_TERMINAL_ID`):

```bash
hmux self                               # who am I: name, id, status, team, owner, plan (reflection; no credential in the guest)
hmux self peers                         # the owner's other machines and their routes; `hmux self integrations` = what I can use, with help commands
hmux tree --json                        # this machine's workspaces/terminals
hmux new-workspace --name tests         # a workspace here
hmux terminal send <term> 'bun test' --keys enter ; hmux terminal wait <term> --pattern 'pass|fail' ; hmux terminal read <term>
hmux terminal wait-exit <term> --timeout 600 ; hmux terminal output <term>   # block until the process exits, then read the full output (not just the screen)
hmux send-key --terminal <term> ctrl+c  # keys into another terminal on this machine
hmux layout apply --name app app.json   # the same layout verb, locally
hmux env ls                             # the same env file
hmux notify --title "done" --body "…"   # lands on the Mac pane showing this terminal
hmux agent claude --timeout 600 "fix the tests"     # runs in this terminal until it exits (it is the wait; exit code passes through; --timeout caps it)
```

To talk to **another** machine (a second agent, a service box), a machine discovers its peers through reflection (`hmux self peers`; use the legacy `hmux vm ls` inventory only when the guest help exposes it; the owner's private network is the trust boundary, so no Mac step is needed — older Mac-written route files still work). Inside a machine, `hmux vm …` takes the peer as its first argument with the same grammar the Mac uses: `hmux vm tree <dst>`, `hmux vm exec <dst> -- <cmd>`, `hmux vm terminal send|read|wait|close <dst> <term> …`, `hmux vm terminal send <dst> <term> enter`, `hmux vm workspace new|rename|close|rm <dst> …`, `hmux vm agent --machine <dst> --agent codex -- "review work/app"` (a durable terminal on the peer running the peer's own agent config), `hmux vm layout export|apply <dst> …`, `hmux vm env set|ls|rm <dst> …`, `hmux vm push <dst> <file> <remote-path>` (one file over the link, secret-safe), `hmux vm agent --machine <dst> … --wait --output` (until the peer's agent exits). No control-plane credential lives in any VM; a machine reaches only machines of its own owner.

A pane showing a machine surface is an ordinary local pane: move, split, reorder, or close it with the local topology verbs ([local topology](../../hmux/SKILL.md)) and the surface catalog follows the pane; closing a pane never kills the machine's terminal. A local workspace that *mirrors* a machine workspace (opened with `hmux vm workspace open`, or bound with `workspace.cloud_vm_bind`) is that workspace seen from the Mac, so its structure is the machine's: a pane moved into it takes its tab there (a pool terminal gets one), a terminal pane closed in it closes that tab (the terminal detaches into the Terminals pool, still running), and a tab or workspace renamed there is renamed on the machine. Closing the local workspace itself (⌘⇧W) only ends the view: the machine workspace and its terminals stay exactly as they were. Panes in any other local workspace are viewers and never touch the machine's layout. Rearranging the machine's topology in full is what `hmux vm tui <id>` is for.

## Notifications

`hmux notify` run inside a machine reaches the user's Mac as data: the machine's daemon records it and the Mac shows it on the pane displaying the terminal it ran in (or at workspace level wherever the machine is open; nowhere if nothing of the machine is on screen). Keep `--title`/`--body` short (128 B / 1 KiB caps, 5 per burst then 1 per second); `--subtitle` folds into the body; Mac selectors (`--workspace`, `--surface`, `--window`, `--tab`, `--panel`), `--reply`, and `--desktop` are ignored there, and nothing can be typed back into the machine from the notification.

## Arrange the view from inside the machine

Use these commands in a daemon terminal (`hmux tree --json` supplies workspace,
screen, pane, split and tab IDs):

```bash
hmux workspace rename <ws> "Review ready"
hmux terminal rename current "Builder" --json
hmux tab rename <tab> "Test results" --json
hmux pane split <pane> right --ratio 0.6 --json
hmux tab move <tab> --workspace <ws> --screen <screen> --pane <destination-pane> --index 0 --json
hmux pane swap <pane> --other-workspace <ws> --other-screen <screen> --other-pane <other-pane> --json
hmux pane resize <pane> --split <split> --ratio 0.65 --json
hmux workspace move <ws> --index 0
hmux tab focus <tab>
hmux notify --title "Review ready" --body "The workspace has the app, logs, and test results."
```

`tab rename` labels one placement; `terminal rename` labels every current placement
of that terminal. Names, including spaces and an empty string, are passed as exact
arguments. A terminal with several views should be moved by its tab ID. Moving,
renaming, swapping, and changing split ratios preserve running terminal processes.
`pane resize` changes layout geometry. Machine resource resizing uses `vm resize` and preserves the existing VM identity and data.

Resource commands use `hmux <resource> <verb> …`; a peer uses
`hmux vm <resource> <verb> <machine> …` (for example,
`hmux vm tab rename <machine> <tab> "Logs"`). Top-level verbs retain their
existing forms, such as `hmux send-key`, `hmux new-workspace`, `hmux agent`, and
`hmux notify`. Existing ID-first daemon syntax is also supported. `hmux workspace
help` lists the full topology grammar.

Arrange the daemon workspace before presenting it. The Mac's
`hmux vm workspace open <machine> <ws>` reads that layout when creating its local
view. These guest commands do not force focus or rearrange an already-open Mac
projection. `layout apply` is for new/empty workspaces; use the commands above to
change an occupied workspace without restarting its agents.

## Browser authentication from guest terminals

`hmux open-url <http-or-https-url>` asks the Mac projecting that exact terminal
to open the URL using its terminal-link preference, without changing workspace
or keyboard focus. Create/heal installs `hmux-open-url`, PATH wrappers for
`xdg-open`, `x-www-browser`, and `sensible-browser`, and Bash/zsh/fish defaults
for `BROWSER` and `GH_BROWSER`. Explicit browser environment overrides survive.
Direct Chrome, `agent-browser`, and CUA keep their existing `DISPLAY=:1` behavior.

The opener uses a bounded, transient request over the authenticated hmux-tui
link, with a frontend delivery acknowledgement. No attached projection, old
binaries, denied placement, disconnect, or timeout prints `Open this URL: <url>`
and exits successfully so the auth CLI keeps polling. URLs are never stored as
notifications or replayed on reconnect. This requires the updated daemon and
Mac client; older combinations safely use the printable fallback.

ブラウザー認証: `hmux open-url <URL>` は、その端末を表示している Mac の
リンク設定に従って URL を開き、ワークスペースや入力フォーカスを変更しません。
接続されていない場合、旧バージョンの場合、配信失敗やタイムアウトの場合は
URL を表示して正常終了します。Chrome、`agent-browser`、CUA の `DISPLAY=:1`
での動作は変わりません。URL は通知として保存されず、再接続時にも再実行されません。

HTTP(S) MIME handlers also use `hmux-open-url`, covering absolute and CLI-bundled
`xdg-open` and GIO. File associations and direct Chrome launchers are unchanged.
HTTP(S) の MIME ハンドラーも hmux を使用します。ファイルの関連付けと
Chrome の直接起動は変更しません。
