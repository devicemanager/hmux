import Foundation

/// Builds the interactive Cloud VM bootstrap from the caller's hmux context.
struct FreestyleInteractiveShellScript: Sendable {
    private let environment: [String: String]
    private let suppressWelcome: Bool

    init(environment: [String: String], suppressWelcome: Bool = false) {
        self.environment = environment
        self.suppressWelcome = suppressWelcome
    }

    var text: String {
        """
        \(suppressWelcome ? "export HMUX_CLOUD_WELCOME=0" : ":")
        \(Self.cloudContextExports(environment: environment))
        export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
        hash -r 2>/dev/null || true
        if command -v zsh >/dev/null 2>&1; then
          touch "$HOME/.hushlogin" 2>/dev/null || true
          if [ ! -e "$HOME/.zshrc" ] || grep -q "hmux-managed zsh defaults" "$HOME/.zshrc" 2>/dev/null; then
            cat > "$HOME/.zshrc" <<'HMUX_USER_ZSHRC'
        # hmux-managed zsh defaults. Edit ~/.zshrc.local for personal overrides.
        mkdir -p "$HOME/.hmux" 2>/dev/null || true
        printf '%s' '/tmp/hmux-cloud-cli.sock' > "$HOME/.hmux/socket_addr" 2>/dev/null || true
        export HMUX_SOCKET_PATH="${HMUX_SOCKET_PATH:-/tmp/hmux-cloud-cli.sock}"
        if [ -r /etc/hmux/zshrc ]; then
          source /etc/hmux/zshrc
        else
          export SHELL="$(command -v zsh)"
          autoload -Uz colors 2>/dev/null && colors
          setopt prompt_subst interactivecomments no_beep hist_ignore_dups share_history 2>/dev/null || true
          PROMPT_EOL_MARK=''
          unsetopt prompt_sp 2>/dev/null || true
          HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
          HISTSIZE="${HISTSIZE:-50000}"
          SAVEHIST="${SAVEHIST:-50000}"
          bindkey -e 2>/dev/null || true
          if [ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
            source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
            ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="${ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE:-fg=8}"
          fi
          : ${HMUX_PROMPT_USER:=hmux-cloud}
          : ${HMUX_PROMPT_CHAR:=$'\\u03bb'}
          PROMPT='%F{magenta}${HMUX_PROMPT_USER}%f in %F{green}%~%f ${HMUX_PROMPT_CHAR} '
        fi
        [ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
        if [ "${HMUX_CLOUD_WELCOME:-1}" != "0" ] && [ -z "${HMUX_CLOUD_WELCOME_SHOWN:-}" ] && [ -t 1 ]; then
          export HMUX_CLOUD_WELCOME_SHOWN=1
          printf '\\033[38;2;0;212;255m  ::\\033[0m\\n'
          printf '\\033[38;2;24;181;250m    ::::              \\033[38;2;0;212;255mc\\033[38;2;24;181;250mm\\033[38;2;48;150;245mu\\033[38;2;124;58;237mx cloud\\033[0m\\n'
          printf '\\033[38;2;48;150;245m      ::::::\\033[0m\\n'
          printf '\\033[38;2;72;119;241m        ::::::\\033[0m        \\033[38;2;130;130;140mpersistent cloud VM\\033[0m\\n'
          printf '\\033[38;2;96;88;239m      ::::::\\033[0m          \\033[38;2;130;130;140mready for coding agents\\033[0m\\n'
          printf '\\033[38;2;110;73;238m    ::::\\033[0m\\n'
          printf '\\033[38;2;124;58;237m  ::\\033[0m\\n'
          printf '\\n'
        fi
        HMUX_USER_ZSHRC
          fi
          if [ ! -e "$HOME/.zshrc.local" ]; then
            cat > "$HOME/.zshrc.local" <<'HMUX_LOCAL_ZSHRC'
        # Personal zsh overrides for this cloud VM.
        # Examples:
        #   HMUX_CLOUD_WELCOME=0
        #   HMUX_PROMPT_USER='hmux-cloud'
        #   HMUX_PROMPT_CHAR='>'
        #   PROMPT='%F{cyan}%n%f:%F{green}%~%f %# '
        HMUX_LOCAL_ZSHRC
          fi
          if command -v tmux >/dev/null 2>&1; then
            hmux_cloud_tty_scope="${HMUX_WORKSPACE_ID:-workspace}-${HMUX_SURFACE_ID:-surface}"
            if [ "$hmux_cloud_tty_scope" = "workspace-surface" ]; then
              hmux_cloud_tty_scope="default"
            fi
            hmux_cloud_tty_scope="$(printf '%s' "$hmux_cloud_tty_scope" | tr -c 'A-Za-z0-9_.-' '-')"
            hmux_cloud_tty_scope="${hmux_cloud_tty_scope#-}"
            hmux_cloud_tty_scope="${hmux_cloud_tty_scope%-}"
            [ -n "$hmux_cloud_tty_scope" ] || hmux_cloud_tty_scope=default
            if [ "$hmux_cloud_tty_scope" != default ] && [ "${HMUX_CLOUD_TMUX_SESSION:-}" = "hmux-cloud" ]; then
              unset HMUX_CLOUD_TMUX_SESSION
            fi
            if [ "$hmux_cloud_tty_scope" = default ]; then
              export HMUX_CLOUD_TMUX_SESSION="${HMUX_CLOUD_TMUX_SESSION:-hmux-cloud}"
            else
              export HMUX_CLOUD_TMUX_SESSION="${HMUX_CLOUD_TMUX_SESSION:-hmux-cloud-$hmux_cloud_tty_scope}"
            fi
            if ! tmux has-session -t "$HMUX_CLOUD_TMUX_SESSION" >/dev/null 2>&1; then
              tmux new-session -d -s "$HMUX_CLOUD_TMUX_SESSION" "exec zsh -l" >/dev/null 2>&1 || unset HMUX_CLOUD_TMUX_SESSION
            fi
            if [ -n "${HMUX_CLOUD_TMUX_SESSION:-}" ] && tmux has-session -t "$HMUX_CLOUD_TMUX_SESSION" >/dev/null 2>&1; then
              tmux set-option -t "$HMUX_CLOUD_TMUX_SESSION" status off >/dev/null 2>&1 || true
              tmux attach-session -t "$HMUX_CLOUD_TMUX_SESSION"
              hmux_tmux_status=$?
              [ "$hmux_tmux_status" -eq 0 ] && exit 0
            fi
          fi
          exec zsh -l
        fi
        exec "${SHELL:-/bin/sh}" -l
        """
    }

    private static func cloudContextExports(environment: [String: String]) -> String {
        var lines: [String] = []
        if let workspaceID = normalizedContextValue(environment["HMUX_WORKSPACE_ID"]) {
            lines.append("export HMUX_WORKSPACE_ID=\(shellSingleQuote(workspaceID))")
            lines.append("export HMUX_TAB_ID=\"$HMUX_WORKSPACE_ID\"")
        }
        if let surfaceID = normalizedContextValue(environment["HMUX_SURFACE_ID"]) {
            lines.append("export HMUX_SURFACE_ID=\(shellSingleQuote(surfaceID))")
            lines.append("export HMUX_PANEL_ID=\"$HMUX_SURFACE_ID\"")
        }
        return lines.isEmpty ? ":" : lines.joined(separator: "\n")
    }

    private static func normalizedContextValue(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shellSingleQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
