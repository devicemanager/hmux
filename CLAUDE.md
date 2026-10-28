# hmux agent notes

Keep repo-wide decisions here; procedures belong in [CONTRIBUTING.md](CONTRIBUTING.md),
[area instructions](#area-instructions) and [task skills](skills/README.md).
Read the matching skill before changing an area, then only the references needed.

**Manaflow AI team members and their agents:** read the private [hmuxterm-hq CLAUDE.md](https://github.com/manaflow-ai/cmuxterm-hq/blob/main/CLAUDE.md) and [AGENTS.md](https://github.com/manaflow-ai/cmuxterm-hq/blob/main/AGENTS.md) before fleet or CI work. They are the entry point for fleet builds, CI routing, agent coordination, and landing rules. Start fleet work at [Fleet and CI: start here](https://github.com/manaflow-ai/cmuxterm-hq/blob/main/build-fleet/FLEET-AND-CI.md). External contributors can ignore this block; those links return 404 for them.

## Verification and isolation

- Before committing, setup or a native build, [choose scoped verification](skills/hmux-testing/references/local-vs-ci-validation.md).
  Start with `python3 scripts/verify-local.py`; docs and portable tooling need no app build.
  Run repository commands only in a [trusted checkout](docs/contributor-verification.md#trust-boundary),
  including `verify-local.py --help`, `--list` and `--repo`. Push does not run checks for you.
- Use [CONTRIBUTING.md](CONTRIBUTING.md#getting-started) for setup. Outside hmuxterm-hq-created
  checkouts, set `HMUX_DEV_BACKEND_MODE=local` for dev builds. Follow [tagged builds](skills/hmux-dev-workflow/references/tagged-builds.md)
  for commands and cache reuse; team fleet tasks start at
  [Fleet and CI: start here](https://github.com/manaflow-ai/cmuxterm-hq/blob/main/build-fleet/FLEET-AND-CI.md).
  Never use bare `xcodebuild` or an untagged `hmux DEV.app`. Clean up only your own tags.
- A same-repo app PR gets a fleet dogfood build and link comment only while it has the
  `dev-build` label. Add it when someone will dogfood the PR, not by default; under load
  the fleet builds the newest push, and the comment says how to build a skipped commit.
- Never quit, kill, relaunch, replace or launch-profile the user's running hmux
  (`/Applications/hmux.app`, `com.hmuxterm.app`), including through a Release build or
  another bundle with that ID. Never set `HMUX_ALLOW_REPLACING_RUNNING_HMUX`; only the
  user may. Reproduce in a tagged build and attach profiling to its PID.
- Dogfood through `HMUX_TAG=<tag> scripts/hmux-debug-cli.sh`, never `/tmp/hmux-cli`.
  Never report raw `.app` paths or `file://` URLs.
- App-linked code (`Sources/`, `CLI/`, `TunnelExtension/` and their packages) must
  remain [Swift 6.0 compatible](skills/hmux-architecture/references/swift-6-0-compatibility.md).

## Area instructions

Read these before working in their scope; nested files may not load automatically:

- `ios/` or `Packages/iOS/`: [ios/AGENTS.md](ios/AGENTS.md).
- `web/` or any hmux Cloud database work: [web/AGENTS.md](web/AGENTS.md).
- `hmux-tui/`: [hmux-tui/AGENTS.md](hmux-tui/AGENTS.md).

## Contributions and publication

Before fixing a bug or adding a feature, search open upstream PRs by symptom or
issue number. Prefer landing an outside contributor's existing PR; push fixups
only when maintainer edits are allowed, and explain the changes. If using their
approach in your own PR, credit them in every such commit with `Co-authored-by`
using their commit email, link your PR from theirs and thank them. Let a human
close it; never close an outside PR without a human-written explanation.

The server directories listed in [LICENSE](LICENSE) (`web/`, `workers/ci-artifacts/`,
`workers/iroh-v2/`, `workers/presence/`, `services/iroh-relay-minter/`,
`hmux-tui/relays/cloudflare-do/`) use the Business Source License, which needs
every outside author's CLA grant. Do not merge a PR that changes those
directories while CLA Assistant is red, and do not copy an outside
contributor's work there under a `Co-authored-by` trailer unless that person
has signed the CLA. Keep code that ships in the macOS or iOS app out of those
directories.

Read [STYLE.md](STYLE.md) before drafting or revising issues, PR descriptions,
RFCs or progress updates. Fill the PR's `## Changelog` section with one
`Added`/`Changed`/`Fixed`/`Removed` line for user-visible changes, otherwise `none`.
Do not edit `CHANGELOG.md` in feature PRs; release tooling owns it.

## CI, review and merge

- Commit the failing behavioral regression before its fix; record the same
  focused command's red and green results ([testing policy](skills/hmux-testing/SKILL.md#reproduce-and-repair)).
  A bug-fix PR body names that command, its failure on the base and its pass on the head,
  then an `### Observed / Not run` section: what you ran and saw, then what you only read
  or didn't run. `gh-merge-green` warns when a fix PR lacks it; it does not block.
- Check executed tests on the current SHA; green skipped jobs do not establish coverage.
  Add `full-ci` only for a user-requested or agreed broad validation plan,
  naming the extra lanes and why ([CI coverage](skills/hmux-testing/references/pr-ci-coverage.md)).
- Keep branches current locally with `scripts/merge-main.sh`; follow
  [the merge-main guide](docs/ci/merge-main.md) and never force-push over its merge.
- `gh pr merge` saying "base branch policy prohibits the merge" means the token lacks the `workflow`
  scope or GitHub timed out, not a rule: run `gh auth refresh -h github.com -s workflow`, or merge with
  `gh api -X PUT repos/OWNER/REPO/pulls/N/merge -f merge_method=squash -f sha=SHA`, which names the cause. Never `--admin`.
- A first implementation pass ends with passed scoped verification and an open PR;
  do not watch CI or run speculative reviews by default.
- Before opening a PR and before merging, check it against [REVIEW.md](REVIEW.md) (draft),
  the mistakes our review history keeps catching.
- Before merging, use a [review subagent](skills/hmux-review/SKILL.md), correctness
  first; a second model is not a review gate. Disclose skipped verification on the PR.
  `main` is nightly: fix forward, do not revert.
- A PR merges when an independent review subagent passes it and it causes no red of its own;
  base reds, flakes and pending checks don't hold it. Don't wait for a person. Ship risky
  user-visible behavior behind a setting or Debug toggle and fix a bad default in the next
  nightly. Merge with `gh-merge-green`; [merge freezes](docs/ci/merge-freeze.md) still hold.
  `gh-merge-green` still waits for the checks it requires; never get around it with
  `--override` or the API merge path.
  Follow [dogfood and merge receipts](skills/hmux-review/SKILL.md#dogfood-and-merge).
  Notify with `hmux notify` when a socket is available.
- A red base (`main` doesn't compile, or CI is red on every PR) is priority zero. Fix it
  directly in its own PR; don't note it and leave it for an owner.

## Implementation rules by task

Use these existing owners instead of duplicating their checklists here:

| Touching | Read before editing |
| --- | --- |
| Typing paths, SwiftUI list/store boundaries, rendering, find layering, UTTypes or OS-specific bugs | [hmux-debugging](skills/hmux-debugging/SKILL.md) |
| Packages, workspace groups, lockfiles or feature flags | [hmux-architecture](skills/hmux-architecture/SKILL.md) |
| Submodules or GhosttyKit | [hmux-ghostty](skills/hmux-ghostty/SKILL.md) |
| User-facing strings, docs or help | [hmux-localization](skills/hmux-localization/SKILL.md); report the localization audit |
| New hmux shortcuts | [hmux-keyboard-shortcuts](skills/hmux-keyboard-shortcuts/SKILL.md) |
| Tests or target wiring | [hmux-testing](skills/hmux-testing/SKILL.md); run `scripts/sync-test-wiring` after adding, renaming or deleting a `hmuxTests/` file |
| Multiple entrypoints or a bug that tests previously missed | [hmux-shared-behavior](skills/hmux-shared-behavior/SKILL.md); share action/mutation paths, verify every entrypoint, and cover the missed repro |

## Remote CLI relay

For v2 socket methods and remote CLI changes, read [relay authorization](skills/hmux-socket-policy/references/remote-relay-authorization.md).
`RemoteRelayCommandPolicy` defaults to deny. Allowlist only for a needed remote
flow, scoped to the session's objects; command-bearing params stay denied on
every method. The PR must analyze local command/content
execution, access to unowned objects and local-state exposure, and include the
required policy tests and ID scoping. Unsafe local effects must be redesigned.
Never allowlist terminal spawn/respawn without live verification that it executes
on the remote host. An allowlist addition without this analysis blocks review.
