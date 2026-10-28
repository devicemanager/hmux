
# hmux-tui: keep the agent shim directory ($HMUX_TUI_AGENT_SHIMS) first on
# PATH. Startup files commonly prepend a directory that holds the real `codex`
# or `claude` (`export PATH="$HOME/.local/bin:$PATH"`), which would start the
# agent without the terminal's hooks. Codex runs its hooks in a shared daemon
# that cannot see this terminal's environment, so only the shim can route
# them here. The startup files ran above; the prompt hook repairs later
# changes, and runs after every hook the startup files installed.
_hmux_tui_agent_shims_first() {
  builtin local ret=$? dir="${HMUX_TUI_AGENT_SHIMS-}"
  if [[ -n "$dir" && -d "$dir" && "$PATH" != "$dir" && "$PATH" != "$dir:"* ]]; then
    builtin local rest=":$PATH:"
    while [[ "$rest" == *":$dir:"* ]]; do
      rest="${rest/":$dir:"/:}"
    done
    rest="${rest#:}"
    rest="${rest%:}"
    PATH="$dir${rest:+:$rest}"
  fi
  builtin return "$ret"
}
if [[ -n "${HMUX_TUI_AGENT_SHIMS-}" ]]; then
  _hmux_tui_agent_shims_first || builtin true
  # Not a bash-preexec preexec hook: a non-zero return there (the previous
  # command's status, kept for the prompt) skips the command under extdebug.
  # A nested shell can inherit PROMPT_COMMAND without the function, hence
  # the redirection, as Ghostty does for its own hook.
  if [[ -n "${bash_preexec_imported-}${__bp_imported-}" ]]; then
    precmd_functions+=(_hmux_tui_agent_shims_first)
  elif [[ $(builtin declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
    PROMPT_COMMAND+=("_hmux_tui_agent_shims_first 2>/dev/null")
  elif [[ -z "${PROMPT_COMMAND-}" ]]; then
    PROMPT_COMMAND="_hmux_tui_agent_shims_first 2>/dev/null"
  else
    [[ "${PROMPT_COMMAND}" =~ (\;[[:space:]]*|$'\n')$ ]] || PROMPT_COMMAND+=";"
    PROMPT_COMMAND+="_hmux_tui_agent_shims_first 2>/dev/null"
  fi
fi
