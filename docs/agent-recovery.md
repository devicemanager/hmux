# Agent recovery

`hmux recover` is the hmux front end for Subrouter's local recovery index. It
lists interrupted Claude sessions and their bounded context without changing
the current workspace:

```sh
hmux recover --query "Mac mini fleet"
hmux recover --session SESSION_ID --focus
hmux recover --session SESSION_ID --json
```

The exact-session form creates a new isolated workspace. Its initial command is
`sr codex` with a bounded continuation prompt, so account routing and Codex's
hmux hooks remain active. The recovery command strips hmux control-plane
environment variables before invoking `sr`; credentials and transcript bodies
are not passed to the hmux socket.
