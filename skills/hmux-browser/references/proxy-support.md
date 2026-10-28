# Proxy Support

hmux browser uses WKWebView networking, so proxy behavior follows macOS/system networking and the app process environment. Related: [commands.md](commands.md), [../SKILL.md](../SKILL.md).

There is no `hmux browser proxy ...` command for per-surface routing: WKWebView has no CDP-style per-context proxy controls. Configure a system or network-level proxy for the environment hmux runs in, or route traffic through an upstream gateway you control.

Verify egress:

```bash
OPEN_JSON="$(hmux --json browser open https://httpbin.org/ip --focus false)"
SURFACE="$(printf '%s' "$OPEN_JSON" | jq -r '.surface_ref // .surface_id // empty')"
[ -n "$SURFACE" ] || { printf '%s\n' 'browser open did not return a surface ref' >&2; exit 1; }
hmux browser --surface "$SURFACE" get text body
```
