import Foundation

extension DockSplitStore {
    static func resolvedWorkingDirectory(_ cwd: String?, baseDirectory: String) -> String {
        guard let cwd, !cwd.isEmpty else { return baseDirectory }
        if cwd.hasPrefix("/") {
            return cwd
        }
        return (baseDirectory as NSString).appendingPathComponent(cwd)
    }

    static func shellStartupScript(command: String, workingDirectory: String) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent(
            "hmux-dock-control-\(UUID().uuidString.lowercased()).sh"
        )
        let encodedCommand = Data(command.utf8).base64EncodedString()
        let encodedWorkingDirectory = Data(workingDirectory.utf8).base64EncodedString()
        let body = """
        #!/bin/sh
        hmux_dock_decode() { printf '%s' "$1" | base64 --decode 2>/dev/null || printf '%s' "$1" | base64 -D 2>/dev/null; }
        hmux_dock_login_shell() {
          hmux_dock_user="$(id -un 2>/dev/null || printf '%s' "${USER:-}")"
          hmux_dock_ds_shell="$(dscl . -read "/Users/$hmux_dock_user" UserShell 2>/dev/null | awk '{print $2; exit}')"
          if [ -n "$hmux_dock_ds_shell" ] && [ -x "$hmux_dock_ds_shell" ]; then printf '%s\\n' "$hmux_dock_ds_shell"
          elif [ -n "${SHELL:-}" ] && [ -x "${SHELL:-}" ]; then printf '%s\\n' "$SHELL"
          else printf '%s\\n' /bin/sh; fi
        }
        hmux_dock_command="$(hmux_dock_decode '\(encodedCommand)')"
        hmux_dock_working_directory="$(hmux_dock_decode '\(encodedWorkingDirectory)')"
        hmux_dock_shell="$(hmux_dock_login_shell)"
        hmux_dock_bundle_bin=""
        if [ -n "${HMUX_BUNDLED_CLI_PATH:-}" ]; then hmux_dock_bundle_bin="$(dirname "$HMUX_BUNDLED_CLI_PATH")"; fi
        export SHELL="$hmux_dock_shell"
        rm -f -- "$0" 2>/dev/null || true
        case "$(basename "$hmux_dock_shell")" in
          fish)
            HMUX_DOCK_BUNDLE_BIN="$hmux_dock_bundle_bin" HMUX_DOCK_START_COMMAND="$hmux_dock_command" HMUX_DOCK_START_DIRECTORY="$hmux_dock_working_directory" "$hmux_dock_shell" -l -c 'if test -n "$HMUX_DOCK_BUNDLE_BIN"; and not contains -- "$HMUX_DOCK_BUNDLE_BIN" $PATH; set -gx PATH "$HMUX_DOCK_BUNDLE_BIN" $PATH; end; if test -n "$HMUX_DOCK_START_DIRECTORY"; cd "$HMUX_DOCK_START_DIRECTORY"; end; eval "$HMUX_DOCK_START_COMMAND"'
            ;;
          *) HMUX_DOCK_BUNDLE_BIN="$hmux_dock_bundle_bin" HMUX_DOCK_START_COMMAND="$hmux_dock_command" HMUX_DOCK_START_DIRECTORY="$hmux_dock_working_directory" "$hmux_dock_shell" -lc 'if [ -n "${HMUX_DOCK_BUNDLE_BIN:-}" ]; then case ":${PATH:-}:" in *":$HMUX_DOCK_BUNDLE_BIN:"*) ;; *) PATH="$HMUX_DOCK_BUNDLE_BIN${PATH:+:$PATH}"; export PATH ;; esac; fi; cd "$HMUX_DOCK_START_DIRECTORY" 2>/dev/null || true; eval "$HMUX_DOCK_START_COMMAND"'
            ;;
        esac
        printf '\\n'
        exec "$hmux_dock_shell" -l
        """
        do {
            try body.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL.path
        } catch {
            return "/bin/sh"
        }
    }
}
