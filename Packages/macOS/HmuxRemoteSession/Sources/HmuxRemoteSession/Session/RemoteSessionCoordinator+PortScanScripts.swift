// Remote shell programs emit positive port rows plus completion markers for
// exactly the scan scopes that produced authoritative negative evidence.
extension RemoteSessionCoordinator {
    /// Builds the TTY-scoped remote listening-port scan program.
    static func remotePortScanScript(
        ttyNames: [String],
        excluding ports: Set<Int>,
        protecting protectedPortsByTTY: [String: Set<Int>]
    ) -> String {
        let ttySet = ttyNames.joined(separator: " ")
        let ttyCSV = ttyNames.joined(separator: ",")
        let excludedPorts = ports.sorted().map(String.init).joined(separator: " ")
        let protectedTTYPorts = protectedPortsByTTY.keys.sorted().flatMap { ttyName in
            (protectedPortsByTTY[ttyName] ?? []).sorted().map { "\(ttyName):\($0)" }
        }.joined(separator: " ")

        return """
        set -eu
        hmux_tracked_ttys=" \(ttySet) "
        hmux_tty_csv='\(ttyCSV)'
        hmux_excluded_ports=" \(excludedPorts) "
        hmux_protected_tty_ports=" \(protectedTTYPorts) "
        hmux_scan_complete=0
        hmux_tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t hmux-ports 2>/dev/null || true)"
        hmux_global_incomplete=""
        hmux_incomplete_ttys=""
        hmux_tab="$(printf '\\t')"
        if [ -n "$hmux_tmpdir" ]; then
          hmux_global_incomplete="$hmux_tmpdir/global-incomplete"
          hmux_incomplete_ttys="$hmux_tmpdir/incomplete-ttys"
          : > "$hmux_incomplete_ttys"
          trap 'rm -rf "$hmux_tmpdir"' EXIT INT TERM
        fi

        hmux_mark_globally_incomplete() {
          [ -n "$hmux_global_incomplete" ] && : > "$hmux_global_incomplete"
          return 0
        }

        hmux_mark_tty_incomplete() {
          hmux_incomplete_tty="$1"
          case "$hmux_tracked_ttys" in
            *" $hmux_incomplete_tty "*) ;;
            *) return 0 ;;
          esac
          [ -n "$hmux_incomplete_ttys" ] && printf '%s\\n' "$hmux_incomplete_tty" >> "$hmux_incomplete_ttys"
          return 0
        }

        hmux_mark_port_owners_incomplete() {
          hmux_ambiguous_port="$1"
          for hmux_owner_tty in $hmux_tracked_ttys; do
            case "$hmux_protected_tty_ports" in
              *" $hmux_owner_tty:$hmux_ambiguous_port "*) hmux_mark_tty_incomplete "$hmux_owner_tty" ;;
            esac
          done
          return 0
        }

        hmux_emit_port() {
          hmux_tty="$1"
          hmux_port="$2"
          case "$hmux_tracked_ttys" in
            *" $hmux_tty "*) ;;
            *) return 0 ;;
          esac
          case "$hmux_excluded_ports" in
            *" $hmux_port "*) return 0 ;;
          esac
          [ "$hmux_port" -ge 1024 ] && [ "$hmux_port" -le 65535 ] || return 0
          printf '%s\\t%s\\n' "$hmux_tty" "$hmux_port"
        }

        hmux_used_ss=0
        if [ -d /proc ] && command -v ss >/dev/null 2>&1; then
          hmux_ss_status=0
          if [ -n "$hmux_tmpdir" ]; then
            hmux_ss_stderr="$hmux_tmpdir/ss.stderr"
            hmux_ss_output="$(ss -ltnpH 2>"$hmux_ss_stderr")" || hmux_ss_status=$?
            [ ! -s "$hmux_ss_stderr" ] || hmux_mark_globally_incomplete
          else
            hmux_ss_output="$(ss -ltnpH 2>/dev/null)" || hmux_ss_status=$?
            hmux_mark_globally_incomplete
          fi
          [ "$hmux_ss_status" -eq 0 ] || hmux_mark_globally_incomplete
          case "$hmux_ss_output" in
            "")
              if [ "$hmux_ss_status" -eq 0 ]; then
                hmux_used_ss=1
                hmux_scan_complete=1
              fi
              ;;
            *pid=*)
              hmux_used_ss=1
              [ "$hmux_ss_status" -ne 0 ] || hmux_scan_complete=1
              printf '%s\\n' "$hmux_ss_output" | while IFS= read -r hmux_line; do
                [ -n "$hmux_line" ] || continue
                hmux_port="$(printf '%s\\n' "$hmux_line" | awk '{print $4}' | sed -E 's/.*:([0-9]+)$/\\1/' | awk '/^[0-9]+$/ { print $1; exit }')"
                if [ -z "$hmux_port" ]; then hmux_mark_globally_incomplete; continue; fi
                hmux_pid_tokens="$(printf '%s\\n' "$hmux_line" | awk '
                  {
                    line = $0
                    while (match(line, /pid=[^,)]*/)) {
                      token = substr(line, RSTART, RLENGTH)
                      if (token ~ /^pid=[0-9]+$/) {
                        print substr(token, 5)
                      } else {
                        print "__hmux_invalid_pid__"
                      }
                      line = substr(line, RSTART + RLENGTH)
                    }
                  }
                ')"
                if [ -z "$hmux_pid_tokens" ]; then
                  hmux_mark_port_owners_incomplete "$hmux_port"
                  continue
                fi
                for hmux_pid in $hmux_pid_tokens; do
                  if [ "$hmux_pid" = "__hmux_invalid_pid__" ]; then
                    hmux_mark_port_owners_incomplete "$hmux_port"
                    continue
                  fi
                  hmux_tty_path="$(readlink "/proc/$hmux_pid/fd/0" 2>/dev/null || true)"
                  if [ -z "$hmux_tty_path" ]; then hmux_mark_port_owners_incomplete "$hmux_port"; continue; fi
                  hmux_tty="${hmux_tty_path##*/}"
                  if [ -z "$hmux_tty" ]; then hmux_mark_port_owners_incomplete "$hmux_port"; continue; fi
                  hmux_emit_port "$hmux_tty" "$hmux_port"
                done
              done
              ;;
          esac
        fi

        if [ "$hmux_used_ss" -eq 0 ] && [ -n "$hmux_tmpdir" ] && command -v lsof >/dev/null 2>&1 && [ -n "$hmux_tty_csv" ]; then
          rm -f "$hmux_global_incomplete"
          : > "$hmux_incomplete_ttys"
          hmux_scan_complete=0
          hmux_pid_tty_map="$hmux_tmpdir/pid_tty"
          hmux_ps_stderr="$hmux_tmpdir/ps.stderr"
          hmux_ps_status=0
          hmux_ps_output="$(ps -t "$hmux_tty_csv" -o pid=,tty= 2>"$hmux_ps_stderr")" || hmux_ps_status=$?
          if [ -s "$hmux_ps_stderr" ]; then exit 0; fi
          # BSD ps exits 1 when a valid selector matches no processes.
          if [ "$hmux_ps_status" -ne 0 ] && { [ "$hmux_ps_status" -ne 1 ] || [ -n "$hmux_ps_output" ]; }; then
            exit 0
          fi
          printf '%s\\n' "$hmux_ps_output" | awk -v globally_incomplete="$hmux_global_incomplete" '
            NF == 2 && $1 ~ /^[0-9]+$/ {
              tty = $2
              sub(/^.*\\//, "", tty)
              if (tty != "") {
                print $1 "\\t" tty
              } else {
                print "1" > globally_incomplete
                close(globally_incomplete)
              }
              next
            }
            NF > 0 {
              print "1" > globally_incomplete
              close(globally_incomplete)
            }
          ' > "$hmux_pid_tty_map"
          if [ ! -s "$hmux_pid_tty_map" ]; then hmux_scan_complete=1; fi
          hmux_pid_csv="$(awk '{print $1}' "$hmux_pid_tty_map" | paste -sd, -)"
          if [ -n "$hmux_pid_csv" ]; then
            hmux_lsof_stderr="$hmux_tmpdir/lsof.stderr"
            hmux_lsof_status=0
            hmux_lsof_output="$(lsof -nP -a -p "$hmux_pid_csv" -iTCP -sTCP:LISTEN -Fpn 2>"$hmux_lsof_stderr")" || hmux_lsof_status=$?
            printf '%s\\n' "$hmux_lsof_output" | awk \
              -v map="$hmux_pid_tty_map" \
              -v globally_incomplete="$hmux_global_incomplete" \
              -v incomplete_ttys="$hmux_incomplete_ttys" '
              function mark_global() {
                print "1" > globally_incomplete
                close(globally_incomplete)
              }
              function mark_tty(value) {
                if (value != "") {
                  print value >> incomplete_ttys
                  close(incomplete_ttys)
                } else {
                  mark_global()
                }
              }
              BEGIN {
                while ((getline < map) > 0) {
                  pid_to_tty[$1] = $2
                }
                close(map)
              }
              $0 ~ /^p[0-9]+$/ {
                pid = substr($0, 2)
                tty = pid_to_tty[pid]
                if (tty == "") mark_global()
                next
              }
              $0 ~ /^p/ {
                tty = ""
                mark_global()
                next
              }
              $0 ~ /^n/ && tty != "" {
                name = substr($0, 2)
                sub(/->.*/, "", name)
                sub(/^.*:/, "", name)
                if (name ~ /^[0-9]+$/) {
                  print tty "\\t" name
                } else {
                  mark_tty(tty)
                }
                next
              }
              $0 ~ /^n/ { mark_global(); next }
              $0 ~ /^f.+$/ { next }
              NF > 0 { mark_tty(tty) }
            ' | while IFS="$hmux_tab" read -r hmux_tty hmux_port; do
              [ -n "$hmux_tty" ] || continue
              [ -n "$hmux_port" ] || continue
              hmux_emit_port "$hmux_tty" "$hmux_port"
            done
            if [ ! -s "$hmux_lsof_stderr" ] && [ "$hmux_lsof_status" -eq 0 ]; then
              hmux_scan_complete=1
            elif [ ! -s "$hmux_lsof_stderr" ] && [ "$hmux_lsof_status" -eq 1 ]; then
              hmux_scan_complete=1
              while IFS="$hmux_tab" read -r hmux_pid hmux_tty; do
                kill -0 "$hmux_pid" 2>/dev/null || hmux_mark_tty_incomplete "$hmux_tty"
              done < "$hmux_pid_tty_map"
            else
              hmux_mark_globally_incomplete
            fi
          fi
        fi
        if [ "$hmux_scan_complete" -eq 1 ] && [ -n "$hmux_global_incomplete" ] && [ ! -e "$hmux_global_incomplete" ]; then
          for hmux_complete_tty in $hmux_tracked_ttys; do
            grep -F -x -e "$hmux_complete_tty" "$hmux_incomplete_ttys" >/dev/null 2>&1 && continue
            printf '%s\\t%s\\n' '\(remoteTTYPortScanCompleteMarker)' "$hmux_complete_tty"
          done
        fi
        exit 0
        """
    }

    /// Builds the host-wide fallback listening-port scan program.
    static func remoteAllPortsScanScript(excluding ports: Set<Int>) -> String {
        let excludedPorts = ports.sorted().map(String.init).joined(separator: " ")

        return """
        set -eu
        hmux_excluded_ports=" \(excludedPorts) "
        hmux_scan_output=""
        hmux_scan_status=127
        hmux_scanner=""
        hmux_tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t hmux-ports 2>/dev/null || true)"
        hmux_scan_stderr=""
        if [ -n "$hmux_tmpdir" ]; then
          hmux_scan_stderr="$hmux_tmpdir/scanner.stderr"
          trap 'rm -rf "$hmux_tmpdir"' EXIT INT TERM
        fi

        hmux_emit_port() {
          hmux_port="$1"
          case "$hmux_excluded_ports" in
            *" $hmux_port "*) return 0 ;;
          esac
          [ "$hmux_port" -ge 1024 ] && [ "$hmux_port" -le 65535 ] || return 0
          printf '%s\\n' "$hmux_port"
        }

        hmux_run_scanner() {
          hmux_scan_status=0
          if [ -n "$hmux_scan_stderr" ]; then
            hmux_scan_output="$("$@" 2>"$hmux_scan_stderr")" || hmux_scan_status=$?
          else
            hmux_scan_output="$("$@" 2>/dev/null)" || hmux_scan_status=$?
          fi
        }

        if command -v ss >/dev/null 2>&1; then
          hmux_scanner=ss
          hmux_run_scanner ss -ltnH
        elif command -v netstat >/dev/null 2>&1; then
          hmux_scanner=netstat
          hmux_run_scanner netstat -lnt
        elif command -v lsof >/dev/null 2>&1; then
          hmux_scanner=lsof
          hmux_run_scanner lsof -nP -iTCP -sTCP:LISTEN
        fi

        hmux_parsed_output=""
        case "$hmux_scanner" in
          ss)
            hmux_parsed_output="$(printf '%s\\n' "$hmux_scan_output" | awk '
              NF == 0 { next }
              {
                name = $4
                sub(/^.*:/, "", name)
                if (name ~ /^[0-9]+$/) print name
                else print "__hmux_incomplete__"
              }
            ')"
            ;;
          netstat)
            hmux_parsed_output="$(printf '%s\\n' "$hmux_scan_output" | awk '
              NF == 0 || $1 == "Proto" || /^Active Internet/ { next }
              {
                name = $4
                sub(/^.*:/, "", name)
                if (name ~ /^[0-9]+$/) print name
                else print "__hmux_incomplete__"
              }
            ')"
            ;;
          lsof)
            hmux_parsed_output="$(printf '%s\\n' "$hmux_scan_output" | awk '
              NF == 0 || $1 == "COMMAND" { next }
              {
                name = $9
                sub(/->.*/, "", name)
                sub(/^.*:/, "", name)
                if (name ~ /^[0-9]+$/) print name
                else print "__hmux_incomplete__"
              }
            ')"
            ;;
        esac

        hmux_parse_complete=1
        case "$hmux_parsed_output" in
          *__hmux_incomplete__*) hmux_parse_complete=0 ;;
        esac
        printf '%s\\n' "$hmux_parsed_output" | while IFS= read -r hmux_port; do
          [ -n "$hmux_port" ] || continue
          [ "$hmux_port" != "__hmux_incomplete__" ] || continue
          hmux_emit_port "$hmux_port"
        done

        hmux_command_complete=0
        if [ -n "$hmux_scan_stderr" ] && [ ! -s "$hmux_scan_stderr" ]; then
          if [ "$hmux_scan_status" -eq 0 ]; then
            hmux_command_complete=1
          elif [ "$hmux_scanner" = lsof ] && [ "$hmux_scan_status" -eq 1 ] && [ -z "$hmux_scan_output" ]; then
            hmux_command_complete=1
          fi
        fi
        if [ "$hmux_command_complete" -eq 1 ] && [ "$hmux_parse_complete" -eq 1 ]; then
          printf '%s\\n' '\(remotePortScanCompleteMarker)'
        fi
        exit 0
        """
    }
}
