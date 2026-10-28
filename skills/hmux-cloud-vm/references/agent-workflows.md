# Agent workflows on hmux Cloud machines

Use the matching recipe after target and capacity authorization in [the skill](../SKILL.md).

## 0. Decide and route (every task starts here)

```bash
hmux vm route --json                  # {machine, created, reason, would_provision}
hmux vm tree                          # what is already running where (terminals, agents, open panes)
```

- Reuse the routed machine when `would_provision` is false — its checkout and deps are warm.
- `would_provision: true` means a new machine slot; check `hmux vm ls` (current plan meter and limits) and prefer Base or an idle machine before creating.
- Long-running or interactive work → `vm agent` / a session terminal, not `exec`.

## 1. Cloud dev box from the local repo ("set it up like magic")

One verb does the whole thing when the project has a recognizable dev command:

```bash
hmux vm dev <id>                       # route → optional push → detect command/port → layout apply --name → open geometry on the Mac
hmux vm dev <id> --port 3000 --name app   # override the detected port and workspace name
hmux vm dev <id> --no-open                # stage the workspace; print `vm workspace open` instead of opening a local pane
hmux vm dev <id> --dry-run --json         # inspect the plan without socket traffic
hmux vm push <id> . work/app --watch   # in a second terminal: keep the machine in sync while you edit locally
```

By hand, the same steps as separate primitives (use these when the dev command needs a pidfile, a database, or a seed step). For a layout, use `vm layout apply --name`; do not create a starter-shell workspace with `vm workspace new --no-open` and then expect it to be empty:

```bash
hmux vm run --sync -- bun install                                # --sync runs inside the synced work/<dir>
# idempotent dev server with a workspace-scoped pidfile/log
hmux vm run --sync -- sh -c 'pid=$(cat .hmux-dev.pid 2>/dev/null); if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && netstat -tlnp 2>/dev/null | grep -q ":3000 .*[ /]$pid/"; then echo "dev server already up (pid $pid owns :3000)"; else rm -f .hmux-dev.pid .hmux-dev.log; if netstat -tln 2>/dev/null | grep -q ":3000 "; then echo "port 3000 is owned by another process" >&2; exit 1; fi; nohup bun run dev > .hmux-dev.log 2>&1 & echo $! > .hmux-dev.pid; fi'
hmux vm run --sync -- sh -c 'for i in $(seq 1 60); do wget -qO- http://localhost:3000 >/dev/null 2>&1 && exit 0; sleep 1; done; tail -n 20 .hmux-dev.log; exit 1'
id=$(hmux vm route --json | jq -r '.machine')                    # the machine the router bound
hmux vm open "$id":port/3000 --print                             # private preview URL; viewer needs the private tunnel
```

Sticky binding means every `vm run` from this directory lands on the same machine. The explicit reuse-or-create spelling still works when you want full control:

```bash
# After provisioning is authorized, use the router-owned pool.
id=$(hmux vm route --provision --json | jq -er '.machine')
hmux vm wait "$id" --wake
hmux vm push "$id" . work/app
hmux vm exec "$id" -- sh -c 'cd work/app && bun install'
```

Finish with `hmux notify --title "Cloud dev server up" --body "<url>"`.

## 1b. Stage a finished workspace for the human (layout + env + code)

The person wants to open one workspace and find everything in place: the checkout, the secrets, an agent pane, a test watcher, the app in a browser pane. Build it headlessly, verify, then open.

```bash
id=$(hmux vm route --json | jq -r '.machine')
hmux vm push "$id" . work/app                                         # code (or a git bundle, §3)
hmux vm env set "$id" --from-file .env.cloud                          # secrets: on the machine, never in the layout
cat > /tmp/app-layout.json <<'JSON'
{"name":"app","cwd":"work/app","layout":{"direction":"horizontal","split":0.6,"children":[
  {"pane":{"surfaces":[{"type":"terminal","name":"claude","command":"claude","focus":true}]}},
  {"direction":"vertical","split":0.5,"children":[
    {"pane":{"surfaces":[{"type":"terminal","name":"tests","command":"bun test --watch"},{"type":"terminal","name":"shell"}]}},
    {"pane":{"surfaces":[{"type":"terminal","name":"dev","command":"bun run dev"},{"type":"browser","url":"http://localhost:3000"}]}}]}]}}
JSON
ws=$(hmux vm layout apply "$id" /tmp/app-layout.json --json | jq -r '.workspace_id')
hmux vm tree "$id"                                                     # the panes exist; agents/tests show their state
hmux vm terminal wait "$id" "$(hmux vm tree "$id" --json | jq -r '.resources[] | select(.title=="dev") | .key')" --pattern 'localhost:3000' --timeout 120
hmux vm workspace open "$id" "$ws"                                     # same geometry on the Mac (or: layout apply … --open)
hmux notify --title "Workspace ready: app" --body "hmux vm open $id/$ws"
```

Reuse a human's arrangement: `hmux vm layout export <id> <ws> > team-layout.json`, commit it next to the repo, and `hmux vm layout apply <fork> team-layout.json` on every fork. A layout the person saved on the Mac (`hmux layout save dev`) applies in the cloud with `--from-saved dev`.

## 2. Hand a task to an agent on the machine

```bash
term=$(hmux vm agent --agent claude --sync --json -- "run the test suite, fix failures, commit on a branch" )
echo "$term" | jq -r '.reattach'                                  # hmux vm open <machine>/<ws>/<term>
hmux vm tree "$(echo "$term" | jq -r '.machine')"                 # [agent claude running] … (open: surface:N)
```

The agent runs as a detached terminal in the machine's hmux-tui session: it keeps going if the pane closes, and `hmux vm open <reattach address>` brings it back (reusing the pane if one already shows it). Fan out by calling `vm agent` once per task with `--machine` pinned to different machines (or forks, §5) and watch them all in `hmux vm tree`.

When you need the result, not the terminal, block until the agent is done and take its output in one call:

```bash
hmux vm agent --agent claude --machine <id> --sync --wait --output --timeout 1800 -- "run the suite, fix failures, commit on a branch" > agent.log; echo "exit=$?"
# fan-out: start each without --wait, then wait on the terminals
for t in $t1 $t2 $t3; do hmux vm terminal wait-exit <id> "$t" --timeout 1800; hmux vm terminal output <id> "$t" > "$t.log"; done
```

`--wait` polls the process (Ctrl-C stops your wait, not the agent), `--output` pages the full scrollback after exit, and the agent's exit code becomes yours (1 on a timeout or signal, with a line saying which).

Inside the machine the agent authenticates like it would locally (its own login, or CodeRouter's env/config under the remote `$HOME`, set once with `vm exec`). Never copy the user's tokens onto a machine unless they ask.

## 2b. Drive an interactive program headlessly (REPL, TUI, watch mode, another agent)

```bash
out=$(hmux surface new-terminal --machine <id> --no-open --json -- sh -lc 'cd "$HOME/work/app" && exec bun test --watch')
term=$(echo "$out" | jq -r '.terminal_id')
cleanup() {
  [ -n "$term" ] || return 0
  hmux vm terminal send <id> "$term" --keys ctrl+c >/dev/null 2>&1 || true
  hmux vm terminal close <id> "$term" >/dev/null 2>&1 || true
}
trap cleanup EXIT
if ! hmux vm terminal wait <id> "$term" --pattern 'Waiting for file changes|passed|failed' --timeout 300; then
  echo "terminal did not become ready" >&2
  exit 1
fi
hmux vm terminal read <id> "$term"                                # the screen a person would see
# `cleanup` stops and closes the task-created watch terminal on every exit path.
```

No pane is attached and no focus moves; a pane the user already has on that terminal shows the same input. `terminal wait` exits 1 on timeout with the screen tail, so branch on it rather than sleeping.

## 2c. Agents talking to agents (same machine, and across machines)

On one machine, an agent drives a sibling terminal headlessly — from the Mac or from inside the machine with the same verbs:

```bash
# from the Mac
hmux vm terminal send <id> <term> 'run the failing test again' --keys enter
hmux vm terminal wait <id> <term> --pattern '❯|\$ $' --timeout 600 && hmux vm terminal read <id> <term>
# from inside the machine (an agent's own hooks/scripts); default target = its own terminal
hmux send-key --terminal <term> enter
hmux terminal read <term>
```

Across machines, discover the owner's available peer routes with `hmux self peers`
or the legacy `hmux vm ls` fallback when the guest's help exposes it, then use the guest's supported verbs. There is no current Mac
enrollment/grant command; older peer-route files remain compatible. See
[guest operations](guest.md) for the host/guest boundary.

```bash
# inside <builder>:
hmux vm agent --machine reviewer --agent codex --name "review" --cwd work/app -- "review the diff on branch feat/x and write REVIEW.md"
hmux vm terminal wait-exit reviewer <term> --timeout 1800                     # the agent's process ended
hmux vm terminal output reviewer <term> | tail -n 40                          # what it said
hmux vm exec reviewer -- cat work/app/REVIEW.md
hmux vm env set reviewer GITHUB_REPO=org/app                       # settings for the peer's shells
hmux vm push reviewer ./deploy_key ~/.ssh/deploy_key --mode 600    # one file over the link into the peer's `hmux file receive`; never through exec
hmux vm agent reviewer --agent codex --wait --output -- "summarize REVIEW.md in three lines"   # until-done on the peer
hmux vm layout apply reviewer review-layout.json --name review     # a workspace on the peer, ready for the human
```

A machine holds no control-plane credential and reaches peers through its owner's
private routes. The earlier Mac enrollment broker is no longer implemented.

### Queue a message into a Codex session

`codex queue` talks to the Codex app-server session store. Run it as the same
user on the target machine that owns the session, with that user's original
`CODEX_HOME`; do not run it from a copied home directory. The queue is local to
that app-server instance, so a successful enqueue in another home does not
reach the visible session.

Use the session's exact UUID (or an exact session name) and quote the message:

```bash
hmux vm exec <id> -- codex queue \
  --thread <codex-thread-uuid> \
  --message 'Please re-check the failing test and report the result.'
```

For a session on the current machine, the equivalent is:

```bash
codex queue --thread <codex-thread-uuid> --message 'Continue with the next step.'
```

`Queued` only means the app-server accepted an item into its queue database; it
does not mean that the agent has read, started, or completed the message. Verify
delivery by inspecting the target session's next turn and visible terminal
state, then read its output through `hmux vm terminal read`/`output` or the
session's normal UI. If the target is currently busy, the message waits for the
session's queue semantics rather than interrupting an in-flight turn.
If the target thread is not loaded, the message remains queued until you open or
resume that thread.

Do not copy `CODEX_HOME`, manually edit `queue_*.sqlite`, or treat a copied
database's `Queued` response as delivery evidence. Those operations enqueue for
the copy only and can race the app-server's writer. If the local control socket
is inaccessible (for example, a cloud container may report `Operation not
permitted` for `/home/<user>/.codex/app-server-control/app-server-control.sock`),
use hmux's terminal path instead:

```bash
hmux vm terminal send <id> <term> 'Continue with the next step.' --keys enter
hmux vm terminal read <id> <term>
```

When a remote app-server endpoint is intentionally exposed, use the installed
CLI's `--remote <wss://…>` together with
`--remote-auth-token-env <ENV_VAR>` and the endpoint's authenticated token. Do
not put an app-server token in a terminal command, prompt, or repository file.
Use `ws://` only for loopback endpoints.

## 3. Repo with history (private repos, no credentials on the machine)

```bash
git bundle create /tmp/repo.bundle --all
hmux vm push <id> /tmp/repo.bundle work/repo.bundle
hmux vm exec <id> -- sh -c 'cd work && git clone repo.bundle app && cd app && git checkout main'
```

Public repos can just clone on the machine: `hmux vm exec <id> -- git clone https://github.com/org/repo work/repo`.

## 4. Builds and tests in the cloud instead of the local Mac

```bash
t=$(hmux surface new-terminal --machine <id> --no-open --json -- sh -c 'cd work/app && make test' | jq -r .terminal_id)
hmux vm terminal wait-exit <id> "$t" --timeout 900        # exited code=<n> | exited signal=<s> | pending (exit 1)
hmux vm terminal output <id> "$t" > test.log              # everything the run printed, not just the visible screen
hmux vm pull <id> work/app/dist ./dist-from-cloud
```

A durable terminal outlives the CLI call and the Mac; `wait-exit` returns the exit code and `output` the full log (`--json` gives `next_offset`, so a long run can be read incrementally with `--after`). For a quick command that finishes in seconds, `hmux vm exec <id> --timeout 300 -- <cmd>` is enough. Report the real outcome from the exit code and the log — a finished wait is not a passed test.

## 5. Parallel experiments with checkpoints and forks

```bash
hmux vm snapshot <id> --name pre-experiment
fork_a=$(hmux vm fork <id> --name try-approach-a --detach --json | jq -r '.id')
fork_b=$(hmux vm fork <id> --name try-approach-b --detach --json | jq -r '.id')
hmux vm agent --agent codex --machine "$fork_a" --no-open -- exec "try approach A in work/app"
hmux vm agent --agent codex --machine "$fork_b" --no-open -- exec "try approach B in work/app"
hmux vm tree                                           # both agents, side by side
hmux vm rm "$fork_a"; hmux vm rm "$fork_b"             # only the forks you created
```

## 6. Desktop and browser tasks

New machines (`hmux vm new`) include TigerVNC with an openbox session and noVNC on 6901; shells get `DISPLAY=:1` while the desktop is up. Drive it from inside the machine (`vm agent` with a computer-use-capable agent — `cua-driver` is preinstalled) and show the human the screen. Historical shell-only machines still have no screen; inspect `vm status` before opening one:

```bash
hmux vm open <id>:desktop              # the screen as a browser pane beside the shell
hmux vm exec <id> -- sh -c 'DISPLAY=:1 xdotool key ctrl+l'   # quick desktop pokes
```

## 6b. Publish a service for a person to open

Use a domain publication when the result must be reachable over HTTPS outside the
owner's private tunnel. Keep `vm open <id>:port/<n>` for private previews; it is
not a shareable public URL.

```bash
# 1. Confirm the VM and port, then create a generated hmux hostname.
hmux vm status <id>
hmux vm ports <id>
publication=$(hmux cloud domains publish <id> 3000 --access personal --json)
echo "$publication" | jq -r '.publication.url'

# 2. For a custom zone, start/continue verification and follow every record shown.
hmux cloud domains verify example.com
# Add the ownership TXT, apex/wildcard routing, and _acme-challenge NS records,
# wait for DNS propagation, then run the same verify command again.
hmux cloud domains publish <id> 3000 --domain app.example.com --access team --team <team-id>

# 3. Check activation and hand off only the URL and intended policy.
hmux cloud domains list --json | jq '.publications[] | {url,hostname,accessMode,state,verification}'
hmux notify --title "Cloud preview ready" --body "Open the URL from hmux cloud domains list"
```

`personal` is the default and requires the publication owner to sign in; `team`
requires a current member of the selected team and a `--team` id; `public` permits
anyone with the URL. `hmux cloud domains access` changes that policy and `rm`
unpublishes it. A custom zone is verified once and can then serve its apex or a
single-label child; a generated hmux hostname needs no customer DNS records. Do
not paste a public URL into logs or agent prompts unless the user intentionally
chose `public`.

## 7. Showing the human

```bash
hmux vm tree <id>                      # the map: which terminal is which, what is already open
hmux vm open <id>/<ws>/<term>          # one terminal as a pane (reuses an open pane)
hmux vm open <id>                      # shell (+ screen on desktop machines)
hmux vm open <id>:desktop              # the screen
hmux vm open <id>:port/3000            # the app they should look at
hmux vm handoff <id>                   # attach block another human/agent can follow
```

Pair with `hmux notify` so they know why a pane appeared. Prefer `--print`/`--detach`/`--no-open` until the moment you intend the user to look; open commands run from an agent never steal focus unless you pass `--focus`; the pane appears in the background marked unread.

## 8. Cleanup etiquette

- New hmux-created machines normally remain available until explicitly paused or stopped; older/provider-managed machines may sleep. Opening or running a command wakes a sleeper, so leaving one for the user to inspect is fine (say so in your handoff).
- If you only opened an existing workspace, close your local view. `vm workspace close` changes the remote workspace: it closes the workspace but leaves its terminals running in the Terminals pool.
- `vm terminal close` ends a terminal; `vm workspace rm` kills every terminal in the workspace. Limit these to resources created for this task, confirm the affected terminals all belong to it, and stay within the authorized cleanup. The same ownership rule applies to deleting scratch machines and forks.
- Never `vm rm` or `vm base reset` a machine you didn't create without explicit user confirmation — `vm rm` deletes it permanently; `vm base reset` creates a new Base generation and retains the old machine.
