# Tagged Builds

Tagged builds isolate app name, bundle ID, debug socket, and DerivedData path so multiple agents and the user's normal app do not collide.

For the local backend used by outside contributors:

```bash
HMUX_DEV_BACKEND_MODE=local ./scripts/reload.sh --tag <tag>
HMUX_DEV_BACKEND_MODE=local ./scripts/reload.sh --tag <tag> --launch
HMUX_DEV_BACKEND_MODE=local ./scripts/reload.sh --tag <tag> --build-only
```

Without `HMUX_DEV_BACKEND_MODE=local`, tagged builds require the shared dev backend
from a hmuxterm-hq checkout. See [contributor setup](../../../CONTRIBUTING.md#getting-started).

A normal reload builds, then terminates the running app with the same tag; `--launch`
also opens the replacement. `--build-only` validates a separately staged bundle
without replacing the app or changing its daemon or tag state, then removes that
validation artifact. It cannot be combined with `--launch`.

For Release variants, `reloads.sh --tag <tag>` uses an isolated staging identity.
`reloadp.sh` uses the stable identity, and `reload2.sh --tag <tag>` also invokes
`reloadp.sh`; both are subject to the running-app restrictions below.

## The user's running hmux

The installed hmux (`/Applications/hmux.app`, bundle id `com.hmuxterm.app`, process `hmux`) holds the user's live agent sessions. Never quit, kill (`pkill -x hmux`, `killall hmux`), relaunch or profile it with `xctrace --launch` or Instruments, and never launch a locally built Release app or any other bundle that uses `com.hmuxterm.app` while it runs. To reproduce the user's state, copy their session into the tagged build instead of touching the running app. Profile only by attaching to a tagged build's pid.

`reloadp.sh` refuses to run while another stable-id hmux is running;
`reload.sh --bundle-id` accepts only `com.hmuxterm.app.debug.*` IDs. A different
bundle with the stable ID also exits instead of replacing the running app
(`SingleInstanceConflictPolicy`). Never bypass these protections;
`HMUX_ALLOW_REPLACING_RUNNING_HMUX=1` is an override only the user may set.

## Prebuilt GhosttyKit

For prebuilt GhosttyKit, run `./scripts/download-prebuilt-ghosttykit.sh` (it verifies the pinned artifact), then use `HMUX_GHOSTTYKIT_PREPROVISIONED=1` with the tagged reload.

## Compile-only checks

Use the tagged `reload.sh --build-only` command above. Reuse the same tag to retain
its DerivedData cache; a new tag starts a cold build. Tags are lowercased and runs
of other characters become `-` (`Fix/ABC-1` becomes `fix-abc-1`).

An app build does not compile or execute the test targets; use the
[test verification guide](../../hmux-testing/references/local-vs-ci-validation.md#native-app-versus-test-compilation)
for those checks. For GhosttyKit source builds, follow the
[Ghostty workflow](../../hmux-ghostty/SKILL.md).

## App path links

A normal `reload.sh` build prints an `App path:` line with the absolute path to the built `.app`. Use it to confirm the tag built. Never put a `file://` URL, a raw `.app` or DerivedData path, or a `/tmp/hmux-<tag>/...` link in chat output.

## Tagged CLI and socket

```bash
HMUX_TAG=<tag> scripts/hmux-debug-cli.sh list-workspaces
HMUX_TAG=<tag> scripts/hmux-debug-cli.sh send --workspace workspace:1 --surface surface:1 "echo ok"
```

The helper refuses to run without `HMUX_TAG`, targets `/tmp/hmux-debug-<tag>.sock`, uses the matching tagged CLI from DerivedData (or, for a fleet build restored with `publish-hq`, from `~/Library/Application Support/hmux/tag-app-cache`), scrubs ambient hmux terminal context (`HMUX_SOCKET`, `HMUX_SOCKET_PASSWORD`, workspace/surface/tab/panel IDs, hmuxd socket, debug log), then sets `HMUX_SOCKET_PATH`, `HMUX_BUNDLE_ID`, and `HMUX_BUNDLED_CLI_PATH` for that tag.

`/tmp/hmux-cli` points at the most recently reloaded build and can target the user's main app socket, so it is never safe for tagged dogfood.

## Cleanup

Before launching a new tagged run, quit older tagged apps you started this session and remove their stale `/tmp` sockets. Remove derived data only when no active task needs it.
