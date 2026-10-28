# vim:ft=zsh
#
# hmux ZDOTDIR bootstrap for zsh.
#
# GhosttyKit already uses a ZDOTDIR injection mechanism for zsh (setting ZDOTDIR
# to Ghostty's integration dir). hmux also needs to run its integration, but
# we must restore the user's real ZDOTDIR immediately so that:
# - /etc/zshrc sets HISTFILE relative to the real ZDOTDIR/HOME (shared history)
# - zsh loads the user's real .zprofile/.zshrc normally (no wrapper recursion)
#
# We restore ZDOTDIR from (in priority order):
# - GHOSTTY_ZSH_ZDOTDIR (set by GhosttyKit when it overwrote ZDOTDIR)
# - HMUX_ZSH_ZDOTDIR (set by hmux when it overwrote a user-provided ZDOTDIR)
# - unset (zsh treats unset ZDOTDIR as $HOME)

# Move the one-shot welcome-banner token path out of the environment before
# user startup files run, so children they exec (tmux, another shell) do not
# inherit it. hmux-zsh-integration.zsh consumes the shell-local copy.
if [[ -n "${HMUX_SHOW_WELCOME_FILE:-}" ]]; then
    builtin typeset -g _HMUX_BOOTSTRAP_WELCOME_FILE="$HMUX_SHOW_WELCOME_FILE"
    builtin unset HMUX_SHOW_WELCOME_FILE
fi

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${HMUX_ZSH_ZDOTDIR+X}" \
   && "$HMUX_ZSH_ZDOTDIR" != "${HMUX_SHELL_INTEGRATION_DIR:-}" \
   && "$HMUX_ZSH_ZDOTDIR" != */Contents/Resources/shell-integration ]]; then
    builtin export ZDOTDIR="$HMUX_ZSH_ZDOTDIR"
    builtin unset HMUX_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
    builtin unset HMUX_ZSH_ZDOTDIR
fi

{
    # zsh treats unset ZDOTDIR as if it were HOME. We do the same.
    builtin typeset _hmux_file="${ZDOTDIR-$HOME}/.zshenv"
    [[ ! -r "$_hmux_file" ]] || builtin source -- "$_hmux_file"

    if [[ -o interactive \
       && -z "${ZSH_EXECUTION_STRING:-}" \
       && "${HMUX_SHELL_INTEGRATION:-1}" != "0" \
       && -n "${HMUX_SHELL_INTEGRATION_DIR:-}" \
       && -r "${HMUX_SHELL_INTEGRATION_DIR}/hmux-zsh-integration.zsh" \
       && "${TERM:-}" == "xterm-256color" \
       && -z "${HMUX_ZSH_RESTORE_TERM:-}" ]]; then
        # Keep startup TERM-compatible prompt/theme selection during shell init,
        # then restore the managed xterm-256color identity before the first
        # interactive command executes.
        builtin export HMUX_ZSH_RESTORE_TERM="$TERM"
        builtin export TERM="xterm-ghostty"
        builtin typeset -g _HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=1
    fi
} always {
    if [[ -o interactive ]]; then
        # We overwrote GhosttyKit's injected ZDOTDIR, so manually load Ghostty's
        # zsh integration if available.
        #
        # We can't rely on GHOSTTY_ZSH_ZDOTDIR here because Ghostty's own zsh
        # bootstrap unsets it before chaining into this hmux wrapper.
        if [[ "${HMUX_LOAD_GHOSTTY_ZSH_INTEGRATION:-0}" == "1" ]]; then
            if [[ -n "${HMUX_SHELL_INTEGRATION_DIR:-}" ]]; then
                builtin typeset _hmux_ghostty="$HMUX_SHELL_INTEGRATION_DIR/ghostty-integration.zsh"
            fi
            if [[ ! -r "${_hmux_ghostty:-}" && -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
                builtin typeset _hmux_ghostty="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
            fi
            [[ -r "$_hmux_ghostty" ]] && builtin source -- "$_hmux_ghostty"
        fi

        # Load hmux integration (unless disabled)
        if [[ "${HMUX_SHELL_INTEGRATION:-1}" != "0" && -n "${HMUX_SHELL_INTEGRATION_DIR:-}" ]]; then
            builtin typeset _hmux_integ="$HMUX_SHELL_INTEGRATION_DIR/hmux-zsh-integration.zsh"
            [[ -r "$_hmux_integ" ]] && builtin source -- "$_hmux_integ"
        fi
    fi

    builtin unset _hmux_file _hmux_ghostty _hmux_integ _HMUX_BOOTSTRAP_WELCOME_FILE
}
