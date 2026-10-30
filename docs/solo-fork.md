# Working on hmux on your own

hmux is a one-person fork of upstream [cmux](https://github.com/manaflow-ai/cmux),
with every cmux/Cmux/CMUX renamed to hmux/Hmux/HMUX. [start-here.md](start-here.md),
[CONTRIBUTING.md](../CONTRIBUTING.md) and [CLAUDE.md](../CLAUDE.md) describe
upstream's process for a team with hundreds of contributors. Most of it does not
apply here. This page is the short version.

Remotes: `origin` is upstream cmux, `private` is this fork (`devicemanager/hmux`).

## Skip

- Issue labels, claiming issues, triage and Discord.
- The CLA, the PR template and changelog lines. Release tooling owns
  `CHANGELOG.md`; leave it alone.
- `full-ci`, `dev-build`, the build fleet, review bots and `gh-merge-green`.
- Tagged dev builds (`scripts/reload.sh --tag`, `ios/scripts/mobile-dev-launch.sh`).
  They need the maintainers' `~/.secrets/hmuxterm-dev.env`.

## The loop

1. Make one focused change. Small commits make upstream syncs easier.
2. Check it:

   ```bash
   python3 scripts/verify-local.py --affected private/main --swift-changed private/main
   ```

   It runs only the static checks your diff touches and needs no build. Pass the
   `private/main` base: the default compares against upstream `origin`, so the
   whole renamed tree counts as changed and the Swift parse fails with
   "Argument list too long". If you
   added, renamed or deleted a file in `hmuxTests/`, run `scripts/sync-test-wiring`
   first.
3. For a bug fix, commit a failing test before the fix when that is cheap.
4. Build and install:
   - Mac: `scripts/build-local-only-mac.sh`. `--skip-build` only re-signs the
     previous build and does not pick up source changes.
   - iPhone: `ios/scripts/build-local-only.sh`, with `--ota-dir`/`--ota-url` for
     an over-the-air install. Bump `CURRENT_PROJECT_VERSION` in
     `ios/Config/Shared.xcconfig`, or iOS may keep the old app.

   Both read their settings from `.env-local` (copy `.env-local.template`).
5. Commit to `main` and push to `private`.

## Syncing upstream

Don't `git merge origin/main`: nearly every line would conflict on the rename.
Use the sync script, which renames upstream on a separate `upstream-hmux`
branch and merges that:

```bash
scripts/hmux-sync-upstream.py            # sync to upstream main and merge
scripts/hmux-sync-upstream.py --build    # also build the Mac app afterwards
```

After a sync, check that the terminal still works on the phone. Strings shared
with code the rename skips (the `ghostty/` submodule, prebuilt binaries, upstream
servers) must stay `cmux`. When a feature silently stops working after a sync,
compare protocol labels on both sides first, then add the label to `PROTECT` in
the sync script and sync again.

## Sending a fix upstream

Only then does the full process apply: branch off `origin/main`, use cmux naming,
fill in the PR template, sign the CLA and follow [start-here.md](start-here.md).
