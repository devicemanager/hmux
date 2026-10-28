// Shared local and peer topology grammar for the in-VM CLI.
export const GUEST_HMUX_TOPOLOGY_SHELL = `# Topology commands share the current local/peer target. The daemon validates
# selectors and destination flags before its authoritative mutation.
guest_topology_command() {
  hmux_tp_noun="\$1"; shift
  hmux_tp_verb="\${1:-help}"
  [ "\$#" -gt 0 ] && shift
  case "\$hmux_tp_verb" in
    help|--help|-h) hmux_message topologyHelp; return ;;
    rename)
      [ "\$#" -ge 2 ] || die_message 2 topologyUsage
      hmux_tp_id="\$1"; hmux_tp_name="\$2"; shift 2
      # The empty name is an intentional value, never a missing argument.
      for hmux_tp_arg in "\$@"; do
        [ "\$hmux_tp_arg" = --json ] || die_message 2 topologyUsage
      done
      if [ "\$hmux_tp_noun" = terminal ]; then
        guest_terminal_rename "\$hmux_tp_id" "\$hmux_tp_name" "\$@"
      else
        exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" "\$@" "\$hmux_tp_noun" "\$hmux_tp_id" rename --name "\$hmux_tp_name"
      fi
      ;;
    new|rm|delete)
      [ "\$hmux_tp_noun" = workspace ] || die_message 2 topologyUsage
      workspace_verb "\$hmux_tp_verb" "\$@"
      ;;
    list|ls)
      exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" "\$hmux_tp_noun" list "\$@"
      ;;
    show|focus|close|move|split|swap|zoom|resize)
      [ "\$#" -ge 1 ] && [ -n "\$1" ] || die_message 2 topologyUsage
      if [ "\$hmux_tp_noun" = workspace ] && [ "\$hmux_tp_verb" = close ]; then
        guest_workspace_close "\$@"
      fi
      hmux_tp_id="\$1"; shift
      case "\$hmux_tp_noun:\$hmux_tp_verb" in
        pane:split)
          case "\${1:-}" in
            left|right|up|down) hmux_tp_direction="\$1"; shift ;;
            *) die_message 2 topologyUsage ;;
          esac
          exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" pane "\$hmux_tp_id" split "--\$hmux_tp_direction" "\$@"
          ;;
        pane:resize)
          exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" pane "\$hmux_tp_id" split ratio set "\$@"
          ;;
        *) exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" "\$hmux_tp_noun" "\$hmux_tp_id" "\$hmux_tp_verb" "\$@" ;;
      esac
      ;;
    *)
      # Preserve the daemon's selector-first grammar and creation verbs.
      exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" "\$hmux_tp_noun" "\$hmux_tp_verb" "\$@"
      ;;
  esac
}

# Remove only the wrapper's compatibility options. Leave daemon options such
# as revision fences and idempotency keys intact for hmux-tui to validate
# before opening its session socket. Rotate only original arguments so quoted
# values retain their bytes and argument boundaries without eval or temp files.
guest_workspace_close() {
  hmux_wc_remaining=\$#
  hmux_wc_workspace=""
  hmux_wc_workspace_seen=0
  hmux_wc_focus_seen=0
  while [ "\$hmux_wc_remaining" -gt 0 ]; do
    hmux_wc_arg="\$1"; shift
    hmux_wc_remaining=\$((hmux_wc_remaining - 1))
    case "\$hmux_wc_arg" in
      --help|-h) hmux_message topologyHelp; exit 0 ;;
      --idempotency-key|--expected-revision|--socket|--session|--machine)
        # An option's value can itself resemble a compatibility option.
        # Keep that pair opaque and let the daemon validate its value.
        [ "\$hmux_wc_remaining" -gt 0 ] || die_message 2 topologyUsage
        hmux_wc_value="\$1"; shift
        hmux_wc_remaining=\$((hmux_wc_remaining - 1))
        set -- "\$@" "\$hmux_wc_arg" "\$hmux_wc_value"
        continue
        ;;
      --workspace|--focus)
        [ "\$hmux_wc_remaining" -gt 0 ] || die_message 2 topologyUsage
        hmux_wc_value="\$1"; shift
        hmux_wc_remaining=\$((hmux_wc_remaining - 1))
        case "\$hmux_wc_value" in ''|--*) die_message 2 topologyUsage ;; esac
        ;;
      --workspace=*|--focus=*) hmux_wc_value="\${hmux_wc_arg#*=}" ;;
      *) set -- "\$@" "\$hmux_wc_arg"; continue ;;
    esac
    case "\$hmux_wc_arg" in
      --workspace|--workspace=*)
        [ "\$hmux_wc_workspace_seen" -eq 0 ] && [ -n "\$hmux_wc_value" ] || die_message 2 topologyUsage
        hmux_wc_workspace_seen=1
        hmux_wc_workspace="\$hmux_wc_value"
        ;;
      --focus|--focus=*)
        [ "\$hmux_wc_focus_seen" -eq 0 ] || die_message 2 topologyUsage
        [ "\$hmux_wc_value" = false ] || die_message 2 topologyCloseFocus
        hmux_wc_focus_seen=1
        ;;
    esac
  done
  if [ "\$hmux_wc_workspace_seen" -eq 1 ]; then set -- "\$hmux_wc_workspace" "\$@"; fi
  [ "\$#" -gt 0 ] || die_message 2 topologyUsage
  case "\$1" in ''|--*) die_message 2 topologyUsage ;; esac
  hmux_wc_workspace="\$1"; shift
  exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" workspace "\$hmux_wc_workspace" close "\$@"
}

# A terminal label is implemented by renaming its exact tab placements, like
# the Mac provider. Use a fresh graph and revision fences; never choose an
# arbitrary view, retry a partial rename, or launch a process to change a name.
guest_terminal_rename() {
  hmux_tr_id="\$1"; hmux_tr_name="\$2"; shift 2
  hmux_tr_json=0
  [ "\${1:-}" != --json ] || hmux_tr_json=1
  if [ "\$hmux_tr_id" = current ] && [ "\$TARGET_LABEL" = local ]; then
    hmux_tr_id="\$(caller_terminal)"
  fi
  hmux_tr_snapshot="\$(tui --json session current snapshot)" || return \$?
  hmux_tr_plan="\$(printf '%s\\n' "\$hmux_tr_snapshot" | jq -ce --arg id "\$hmux_tr_id" '
    (.value // .) as \$s
    | [\$s.terminals[] | select(.id == \$id)] as \$terminals
    | [\$s.tabs[] | select(.content_kind == "terminal" and .content_id == \$id) | .id] | unique
    | select(length > 0 and (\$terminals | length) == 1) as \$tabs
    | select(all(\$tabs[]; type == "string" and test("^tab_[A-Za-z0-9]+\$")))
    | select((\$s.session.generation | type) == "string" and (\$s.session.generation | length) > 0)
    | select((\$s.session.revision | type) == "string" and (\$s.session.revision | test("^[0-9]+\$")))
    | {tabs: \$tabs, generation: \$s.session.generation, revision: \$s.session.revision}
  ')" || die_message 1 topologyRenameTarget "\$hmux_tr_id"
  hmux_tr_revision="\$(printf '%s\\n' "\$hmux_tr_plan" | jq -r .revision)"
  hmux_tr_generation="\$(printf '%s\\n' "\$hmux_tr_plan" | jq -r .generation)"
  hmux_tr_tabs="\$(printf '%s\\n' "\$hmux_tr_plan" | jq -r '.tabs[]')"
  hmux_tr_count=0
  for hmux_tr_tab in \$hmux_tr_tabs; do
    hmux_tr_receipt="\$(tui --json --expected-revision "\$hmux_tr_revision" tab "\$hmux_tr_tab" rename --name "\$hmux_tr_name")" ||
      die_message 1 topologyRenamePartial "\$hmux_tr_id" "\$hmux_tr_count"
    # Compare decimal revisions as strings so UInt64 cursors retain precision.
    hmux_tr_revision="\$(printf '%s\\n' "\$hmux_tr_receipt" | jq -er --arg gen "\$hmux_tr_generation" --arg prev "\$hmux_tr_revision" --arg tab "\$hmux_tr_tab" '
      select(.generation == \$gen and .value.id == \$tab)
      | .revision | select(type == "string" and test("^[0-9]+\$"))
      | select(length > (\$prev | length) or (length == (\$prev | length) and . > \$prev))
    ')" || die_message 1 topologyRenameReceipt "\$hmux_tr_id"
    hmux_tr_count=\$((hmux_tr_count + 1))
  done
  if [ "\$hmux_tr_json" -eq 1 ]; then
    printf '%s\\n' "\$hmux_tr_plan" | jq --arg id "\$hmux_tr_id" --arg name "\$hmux_tr_name" --arg revision "\$hmux_tr_revision" \\
      '{terminal_id: \$id, tab_ids: .tabs, name: \$name, generation: .generation, revision: \$revision}'
  else
    hmux_message topologyRenamed "\$hmux_tr_id" "\$hmux_tr_count"
  fi
}
`;
