/** Read-only CodeRouter discovery through the VM's edge identity. */
export const GUEST_CODEROUTER_SHELL = `guest_coderouter_accounts() {
  hmux_ca_json=false
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --json) hmux_ca_json=true ;;
      *) die_message 2 unknownCodeRouter "\$hmux_arg" ;;
    esac
  done
  require_coderouter
  hmux_ca_native="\$(hmux_curl -fsS --connect-timeout 5 --max-time 20 \\
    -H "authorization: Bearer \$hmux_coderouter_key" "\${hmux_coderouter_url%/}/api/coderouter/accounts")" || return 1
  hmux_ca_claude="\$(hmux_curl -fsS --connect-timeout 5 --max-time 20 \\
    -H "authorization: Bearer \$hmux_coderouter_key" "\${hmux_coderouter_url%/}/api/coderouter/claude-upstream")" || return 1
  # A mismatched response is an error; never combine two organizations.
  hmux_ca_result="\$(jq -en --argjson native "\$hmux_ca_native" --argjson claude "\$hmux_ca_claude" '
    if (\$native.teamId | type) != "string" or \$native.teamId != \$claude.teamId then error("team_mismatch")
    else {teamId: \$native.teamId, accounts: (\$native.accounts + [\$claude.accounts[] | . + {provider: "claude"}])} end
  ')" || return 1
  if [ "\$hmux_ca_json" = true ] || [ "\${HMUX_OUTPUT:-}" = json ]; then
    printf '%s\\n' "\$hmux_ca_result"
  else
    printf '%s\\n' "\$hmux_ca_result" | jq -r --arg team "\$(hmux_message labelTeam)" '
      "\\(\$team): \\(.teamId)", (.accounts[] | [.provider, .label, .state] | @tsv)'
  fi
}

guest_coderouter_org() {
  [ "\${1:-current}" = current ] || die_message 2 accountHostOnly "org \${1:-}"
  [ "\$#" -eq 0 ] || shift
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in --json) ;; *) die_message 2 unknownCodeRouter "\$hmux_arg" ;; esac
  done
  require_coderouter
  hmux_ca_org="\$(hmux_curl -fsS --connect-timeout 5 --max-time 20 \\
    -H "authorization: Bearer \$hmux_coderouter_key" "\${hmux_coderouter_url%/}/api/coderouter/organizations")" || return 1
  printf '%s\\n' "\$hmux_ca_org" | jq -e '.fixed == true and (.teams | length) == 1 and .selectedTeamId == .teams[0].id' >/dev/null || return 1
  if [ "\${1:-}" = --json ] || [ "\${HMUX_OUTPUT:-}" = json ]; then
    printf '%s\\n' "\$hmux_ca_org" | jq '{teamId: .selectedTeamId, fixed: true}'
  else
    printf '%s\\n' "\$hmux_ca_org" | jq -r '.selectedTeamId'
  fi
}
`;

/**
 * `cr use [own|team|auto] [claude|codex|opencode]... [--json]`: how each coding
 * agent signs in on this machine (all three when none is named). The mode
 * itself is resolved by the image's /etc/hmux/agent-auth.sh, the same file the
 * agent launchers read at every launch, so the report here and a launch can
 * never disagree. This only records the choice.
 */
export const GUEST_CODEROUTER_USE_SHELL = `guest_coderouter_use() {
  hmux_use_mode=""
  hmux_use_agents=""
  hmux_use_json=false
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      own|team|auto) [ -z "\$hmux_use_mode" ] || die_message 2 useOneMode; hmux_use_mode="\$hmux_arg" ;;
      claude|codex|opencode)
        case " \$hmux_use_agents " in
          *" \$hmux_arg "*) ;;
          *) hmux_use_agents="\${hmux_use_agents:+\$hmux_use_agents }\$hmux_arg" ;;
        esac
        ;;
      status|show) ;;
      --json) hmux_use_json=true ;;
      --help|-h|help) hmux_message useHelp; return 0 ;;
      *) die_message 2 useUnknown "\$hmux_arg" ;;
    esac
  done
  [ -n "\$hmux_use_agents" ] || hmux_use_agents="claude codex opencode"
  [ "\${HMUX_OUTPUT:-}" != json ] || hmux_use_json=true
  hmux_use_lib="\${HMUX_AGENT_AUTH_LIB:-/etc/hmux/agent-auth.sh}"
  [ -f "\$hmux_use_lib" ] || die_message 2 useUnsupported
  . "\$hmux_use_lib"
  for hmux_use_agent in \$hmux_use_agents; do
    hmux_use_file="\$(hmux_agent_auth_file "\$hmux_use_agent")"
    case "\$hmux_use_mode" in
      own|team)
        if { mkdir -p "\${hmux_use_file%/*}" && printf '%s\\n' "\$hmux_use_mode" > "\$hmux_use_file.tmp" && mv -f "\$hmux_use_file.tmp" "\$hmux_use_file"; } 2>/dev/null; then :; else
          die_message 1 useWriteFailed "\$hmux_use_file"
        fi
        ;;
      auto) rm -f "\$hmux_use_file" 2>/dev/null || die_message 1 useWriteFailed "\$hmux_use_file" ;;
    esac
  done
  # A Claude key or endpoint the caller exported itself outranks either mode.
  hmux_use_override=""
  if [ -n "\${ANTHROPIC_API_KEY:-}\${ANTHROPIC_BASE_URL:-}" ] && [ "\${ANTHROPIC_BASE_URL:-}" != "\${HMUX_CODEROUTER_URL:-}" ]; then hmux_use_override=1; fi
  # The account check reads the model-plane origin; a missing plane answers
  # "unknown", never an error, so the switch works offline.
  if [ -f "\$HOME/.config/hmux/model-plane.env" ] || [ -f /etc/hmux/model-plane.env ]; then load_model_env; fi
  # Report the current answer, and let the next launch see it too.
  rm -f "\$HOME/.cache/hmux/agent-access" 2>/dev/null || :
  hmux_use_sep=""
  [ "\$hmux_use_json" = false ] || printf '{"agents":['
  for hmux_use_agent in \$hmux_use_agents; do
    hmux_agent_auth_resolve "\$hmux_use_agent"
    if [ "\$hmux_use_json" = true ]; then
      printf '%s{"agent":"%s","mode":"%s","reason":"%s","chosen":%s}' "\$hmux_use_sep" "\$hmux_use_agent" "\$hmux_agent_auth_mode" "\$hmux_agent_auth_reason" \\
        "\$([ "\$hmux_agent_auth_reason" = chosen ] && echo true || echo false)"
      hmux_use_sep=,
      continue
    fi
    case "\$hmux_use_agent" in
      claude) hmux_use_name="Claude Code"; hmux_use_login="/login in Claude Code" ;;
      codex) hmux_use_name=Codex; hmux_use_login="codex login (codex login --device-auth without a browser)" ;;
      *) hmux_use_name=OpenCode; hmux_use_login="opencode auth login" ;;
    esac
    case "\$hmux_agent_auth_reason" in
      env) hmux_use_reason="\$(hmux_message useReasonEnv "HMUX_\$(printf '%s' "\$hmux_use_agent" | tr '[:lower:]' '[:upper:]')_AUTH")" ;;
      chosen) hmux_use_reason="\$(hmux_message useReasonChosen)" ;;
      login) hmux_use_reason="\$(hmux_message useReasonLogin)" ;;
      team-account) hmux_use_reason="\$(hmux_message useReasonTeamAccount)" ;;
      no-team-account) hmux_use_reason="\$(hmux_message useReasonNoTeamAccount)" ;;
      team-unreachable) hmux_use_reason="\$(hmux_message useReasonTeamUnreachable)" ;;
      *) hmux_use_reason="\$(hmux_message useReasonTeamUnknown)" ;;
    esac
    if [ "\$hmux_agent_auth_mode" = own ]; then
      hmux_message useModeOwn "\$hmux_use_name" "\$hmux_use_reason"
      [ "\$hmux_agent_auth_reason" = login ] || hmux_message useOwnLogin "\$hmux_use_login"
    else
      hmux_message useModeTeam "\$hmux_use_name" "\$hmux_use_reason"
      if [ "\$hmux_agent_auth_reason" = chosen ]; then
        if hmux_agent_team_access "\$hmux_use_agent"; then hmux_use_rc=0; else hmux_use_rc=\$?; fi
        [ "\$hmux_use_rc" -ne 1 ] || hmux_message useTeamNoAccount "\$hmux_use_name" "cr add \$hmux_use_agent" "\$hmux_use_agent"
      fi
    fi
    if [ "\$hmux_use_agent" = claude ] && [ -n "\$hmux_use_override" ]; then hmux_message useEnvOverride; fi
  done
  if [ "\$hmux_use_json" = true ]; then printf ']}\\n'; return 0; fi
  if [ -n "\$hmux_use_mode" ]; then hmux_message useNextLaunch; fi
}
`;
