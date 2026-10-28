# hmux-vault

`hmux-vault` discovers local coding-agent session transcripts and syncs them to
hmux Vault cloud storage. Round 1 supports Claude Code, Codex, and pi.

## Install

```bash
go build ./cmd/hmux-vault
```

## Commands

```bash
hmux-vault login
hmux-vault scan
hmux-vault sync
hmux-vault resume <session-id>
hmux-vault status
hmux-vault logout
```

`login` starts a device-code flow, prints a verification URL and user code, and
stores Stack Auth tokens in `~/.config/hmux-vault/auth.json` with mode `0600`.
`sync` uploads changed transcripts directly to S3-compatible object storage via
presigned URLs. `resume` restores a missing transcript from cloud storage and
prints the command the agent expects.

Useful flags:

```bash
hmux-vault --json scan
hmux-vault sync --agent codex --dry-run
hmux-vault sync --limit 25
hmux-vault resume --agent claude <session-id>
hmux-vault resume --force <session-id>
```

## Environment

- `HMUX_VAULT_API_BASE`: web API base URL. Defaults to `https://cmux.com`.
- `HMUX_VAULT_CONFIG_DIR`: override the auth token directory.
- `HMUX_VAULT_STATE_DIR`: override the sync state directory.
- `CLAUDE_CONFIG_DIR`: override Claude Code config discovery.
- `CODEX_HOME`: override Codex discovery.

Default local state lives in `~/.local/state/hmux-vault/state.json`.
