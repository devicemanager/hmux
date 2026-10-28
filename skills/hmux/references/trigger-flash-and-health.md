# Trigger Flash and Surface Health

Flash a surface or workspace for visual confirmation in the UI:

```bash
hmux trigger-flash --surface surface:7
hmux trigger-flash --workspace workspace:2
```

Detect hidden, detached, or non-windowed surfaces before routing focused input when UI state may be stale:

```bash
hmux surface-health
hmux surface-health --workspace workspace:2
```
