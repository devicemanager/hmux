#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

APP="$TMP_DIR/hmux.app"
mkdir -p \
  "$APP/Contents/MacOS" \
  "$APP/Contents/Resources/bin" \
  "$APP/Contents/PlugIns/HmuxDockTilePlugin.plugin/Contents/MacOS" \
  "$APP/Contents/Library/SystemExtensions/hmuxTunnel.systemextension/Contents/MacOS" \
  "$APP/Contents/Frameworks" \
  "$APP/Contents/Resources/bin/hmux-tui-ssh" \
  "$TMP_DIR/tools"

for path in \
  "$APP/Contents/MacOS/hmux" \
  "$APP/Contents/Resources/bin/hmux" \
  "$APP/Contents/Resources/bin/hmux-tui" \
  "$APP/Contents/Resources/bin/hmux-diff-sidecar" \
  "$APP/Contents/Resources/bin/ghostty" \
  "$APP/Contents/PlugIns/HmuxDockTilePlugin.plugin/Contents/MacOS/HmuxDockTilePlugin" \
  "$APP/Contents/Library/SystemExtensions/hmuxTunnel.systemextension/Contents/MacOS/hmuxTunnel" \
  "$APP/Contents/Frameworks/libhmux_command_palette_nucleo_ffi.dylib" \
  "$APP/Contents/Frameworks/Sparkle.framework"
do
  mkdir -p "$(dirname "$path")"
  printf '#!/bin/sh\nexit 0\n' > "$path"
  chmod +x "$path"
done

# hmux-tui SSH bootstrap payloads are installed 0644. The macOS ones are Mach-O
# and must be stripped; the Linux ones are ELF and arrive already stripped.
for target in aarch64-apple-darwin x86_64-apple-darwin aarch64-unknown-linux-musl x86_64-unknown-linux-musl; do
  printf 'payload\n' > "$APP/Contents/Resources/bin/hmux-tui-ssh/hmux-tui-$target"
  chmod 644 "$APP/Contents/Resources/bin/hmux-tui-ssh/hmux-tui-$target"
done
printf '{}\n' > "$APP/Contents/Resources/bin/hmux-tui-ssh/manifest.json"

cat > "$TMP_DIR/tools/file" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  *"/Contents/MacOS/hmux"|*"/Contents/Resources/bin/hmux"|*"/Contents/Resources/bin/hmux-tui"|*"/Contents/Resources/bin/hmux-diff-sidecar"|*"HmuxDockTilePlugin"|*"/Contents/MacOS/hmuxTunnel"|*"libhmux_"*|*"-apple-darwin")
    printf '%s: Mach-O universal binary\n' "$1"
    ;;
  *)
    printf '%s: POSIX shell script\n' "$1"
    ;;
esac
EOF
chmod +x "$TMP_DIR/tools/file"

cat > "$TMP_DIR/tools/strip" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HMUX_STRIP_LOG"
EOF
chmod +x "$TMP_DIR/tools/strip"

HMUX_STRIP_LOG="$TMP_DIR/strip.log" \
HMUX_FILE_TOOL="$TMP_DIR/tools/file" \
HMUX_STRIP_TOOL="$TMP_DIR/tools/strip" \
  "$ROOT/scripts/strip-release-bundle.sh" "$APP"

# hmux's own executables lose every symbol dyld doesn't need (plain strip
# keeps undefined and dynamically referenced ones): crashes symbolicate from the
# uploaded dSYMs. Plug-ins, libraries and extensions keep their global symbols.
expected="$TMP_DIR/expected.log"
printf '%s\n' \
  "$APP/Contents/MacOS/hmux" \
  "$APP/Contents/Resources/bin/hmux" \
  "$APP/Contents/Resources/bin/hmux-tui" \
  "$APP/Contents/Resources/bin/hmux-diff-sidecar" \
  "-S -x $APP/Contents/Resources/bin/hmux-tui-ssh/hmux-tui-aarch64-apple-darwin" \
  "-S -x $APP/Contents/Resources/bin/hmux-tui-ssh/hmux-tui-x86_64-apple-darwin" \
  "-S -x $APP/Contents/PlugIns/HmuxDockTilePlugin.plugin/Contents/MacOS/HmuxDockTilePlugin" \
  "-S -x $APP/Contents/Frameworks/libhmux_command_palette_nucleo_ffi.dylib" \
  "-S -x $APP/Contents/Library/SystemExtensions/hmuxTunnel.systemextension/Contents/MacOS/hmuxTunnel" \
  > "$expected"

if ! diff -u "$expected" "$TMP_DIR/strip.log"; then
  echo "strip-release-bundle.sh stripped the wrong files" >&2
  exit 1
fi
