# Default only. Set PS1 after sourcing /etc/hmux/bashrc in ~/.bashrc to
# replace it, or remove that source line to use your own shell setup.
# Only builtins run before each prompt. The name lives in a file, so open
# shells see renames without an environment update or a child process.
if ! declare -F __hmux_prompt_name >/dev/null; then
  __hmux_read_vm_name() {
    IFS= read -r __hmux_vm_name 2>/dev/null < /etc/hmux/vm-name || __hmux_vm_name=hmux
  }
  # Report the working directory to the hmux-tui daemon with OSC 7 so the
  # Cloud workspace row follows `cd`. The daemon accepts only a file URL on
  # this host, so every byte outside the unreserved set is percent-encoded.
  __hmux_report_cwd() {
    local LC_ALL=C rest="$PWD" safe encoded=""
    while [ -n "$rest" ]; do
      safe="${rest%%[!a-zA-Z0-9/_.~-]*}"
      encoded+="$safe"
      rest="${rest#"$safe"}"
      if [ -n "$rest" ]; then
        printf -v safe '%%%02X' "'${rest:0:1}"
        encoded+="$safe"
        rest="${rest#?}"
      fi
    done
    printf '\e]7;file://%s%s\a' "${HOSTNAME:-localhost}" "$encoded"
  }
  # Warm template shell. The Cloud snapshot keeps the first terminal's shell
  # running; the bake arms it (/run/hmux/template-arm) and this shell's first
  # prompt waits here until the clone's daemon has adopted the terminal and
  # written the new session and terminal ids (/run/hmux/bound). The ids in
  # this shell's environment name the snapshot builder until then, so no
  # prompt, command or agent hook may run before they are replaced. After a
  # clone starts (/run/hmux/clone-started) the wait is bounded (3 s, or
  # HMUX_PROMPT_TEMPLATE_WAIT_US): on timeout the builder's ids are removed
  # rather than kept, and each later prompt imports the binding once it
  # appears. It then waits up to 1.5 s for the machine name, so the first
  # prompt normally shows hmux@<slug> and hmux-prompt-sync does not need to
  # clear and interrupt it.
  __hmux_template_import() {
    local key value
    while IFS='=' read -r key value; do
      case $key in
        HMUX_TUI_SESSION_ID | HMUX_TUI_TERMINAL_ID) export "$key=$value" ;;
      esac
    done < "$1"
  }
  __hmux_template_gate() {
    local waited=0 run=${HMUX_PROMPT_RUN_DIR:-/run/hmux} since=
    local limit=${HMUX_PROMPT_TEMPLATE_WAIT_US:-3000000}
    : > "$run"/template-shell-ready 2>/dev/null
    while [ ! -e "$run"/bound ]; do
      if [ -e "$run"/clone-started ]; then
        # Wall-clock bound (EPOCHREALTIME, microseconds) after the clone
        # started. Counting iterations would include fork time.
        [ -n "$since" ] || since=${EPOCHREALTIME/./}
        [ $((${EPOCHREALTIME/./} - since)) -ge "$limit" ] && break
      fi
      sleep 0.05
    done
    unset HMUX_TUI_SESSION_ID HMUX_TUI_TERMINAL_ID
    if [ -r "$run"/bound ]; then
      __hmux_template_import "$run"/bound
    else
      __hmux_template_unbound=1
    fi
    waited=0
    while [ "$waited" -lt 30 ]; do
      __hmux_read_vm_name
      [ "$__hmux_vm_name" != hmux ] && break
      sleep 0.05
      waited=$((waited + 1))
    done
    [ "$__hmux_vm_name" != hmux ] && : > "$run"/first-prompt-named 2>/dev/null
    return 0
  }
  __hmux_prompt_name() {
    local status=$?
    if [[ ${__hmux_template_shell:-} ]]; then
      __hmux_template_shell=
      __hmux_template_gate
    elif [[ ${__hmux_template_unbound:-} ]] && [ -r "${HMUX_PROMPT_RUN_DIR:-/run/hmux}"/bound ]; then
      __hmux_template_unbound=
      __hmux_template_import "${HMUX_PROMPT_RUN_DIR:-/run/hmux}"/bound
    fi
    __hmux_read_vm_name
    __hmux_report_cwd
    return "$status"
  }
  PROMPT_COMMAND=(__hmux_prompt_name "${PROMPT_COMMAND[@]}")
  # Exactly one shell consumes the bake's arm file and becomes the template.
  if [ -e "${HMUX_PROMPT_RUN_DIR:-/run/hmux}/template-arm" ] \
    && rm "${HMUX_PROMPT_RUN_DIR:-/run/hmux}/template-arm" 2>/dev/null; then
    __hmux_template_shell=1
  fi
fi
__hmux_read_vm_name
PS1='\[\e[35m\]\u@${__hmux_vm_name}\[\e[0m\] in \[\e[32m\]\w\[\e[0m\]\[\e[33m\] λ\[\e[0m\] '
