# Handles and Identify

Most v2-backed commands accept a UUID, a short ref (`window:N`, `workspace:N`, `pane:N`, `surface:N`), or an index where legacy index-based commands still allow it.

```bash
hmux identify --json                                  # focused topology + caller resolution
hmux identify --workspace workspace:2                 # route relative actions from a known anchor
hmux identify --workspace workspace:2 --surface surface:8

hmux --json --id-format both identify                 # refs plus UUIDs
hmux --json --id-format uuids identify
```
