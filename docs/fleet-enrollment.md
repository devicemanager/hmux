# HMUX fleet machine onboarding

Use this path for HMUX-controlled Mac or Linux hardware that should be eligible for reviewed repository-owned work while existing owners keep their responsibilities.

SSH, MDM/configuration management, the HMUX controller, GitHub Actions, hosted runners, and direct operator access remain separate coordination systems. HMUX defines what a semantic workload means. Glaeda records whether the machine is enrolled for that role and whether a current exact acceptance result exists.

Glaeda tracking: teamleaderleo/glaeda#1056 and #1057.

## Contract boundary

The first reviewed role bindings are:

| Fleet role | HMUX workload profile |
| --- | --- |
| `hmux_macos_native_build` | `hmux.macos.dev-check@1` |
| `hmux_linux_ci` | `hmux.ci.guard@1` |

The profile registry in `scripts/ci/hmux-workload-profiles.json` owns repository entrypoint, semantic validator, reviewed environment class, expected result class, timeout, resource class, network class, benchmark state classes, runtime inputs, and artifact classes. Profile children receive a closed environment; arbitrary caller PATH, SSH agents, tokens, and unrelated CI variables do not flow into the workload.

Glaeda consumes that profile identity and the canonical `hmux-workload-result/v1` emitted by `scripts/ci/hmux_workload_profile.py`. Glaeda does not maintain another list of HMUX commands or another HMUX pass/fail definition.

Role enrollment is routing-candidate evidence only. Glaeda still performs fresh local admission before execution, and higher-level routing policy still decides whether an eligible node should receive work.

## Current preferred path

Maintainers onboarding current HMUX fleet hardware should use Glaeda's maintained
[HMUX fleet enrollment guide](https://github.com/teamleaderleo/glaeda/blob/main/docs/HMUX_FLEET_ENROLLMENT.md)
and its `glaeda-mini-setup` and `glaeda-mini-enroll` commands. That guide owns
host setup, receipts, preflight, and recovery. The manual bootstrap below is a
contract and development fallback for reproducing the lower-level enrollment
steps; it is not a second fleet installer.

## 1. Prepare the machine

Have exact HMUX and Glaeda checkouts locally. Package installation, accounts, SSH/Tailscale, MDM, power policy, and machine naming stay with the existing operator path.

Common variables:

```bash
set -euo pipefail
GLAEDA_ROOT=/absolute/path/to/glaeda
HMUX_ROOT=/absolute/path/to/hmux
FLEET_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/glaeda/hmux-fleet"
GLAEDA_INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/glaeda/hmux-fleet"
GLAEDA_BIN="$GLAEDA_INSTALL_ROOT/glaeda"
umask 077
install -d -m 700 "$FLEET_ROOT" "$FLEET_ROOT/acceptance" "$GLAEDA_INSTALL_ROOT"
BOOTSTRAP="$(mktemp "$FLEET_ROOT/.bootstrap.XXXXXX")"
chmod 600 "$BOOTSTRAP"

cd "$GLAEDA_ROOT"
./scripts/bootstrap
cargo build --locked --release --bin glaeda
if test -f "$GLAEDA_BIN" && ! test -e "$GLAEDA_INSTALL_ROOT/glaeda.rollback"; then
  cp -p "$GLAEDA_BIN" "$GLAEDA_INSTALL_ROOT/glaeda.rollback"
fi
install -m 755 target/release/glaeda "$GLAEDA_INSTALL_ROOT/.glaeda.next"
mv "$GLAEDA_INSTALL_ROOT/.glaeda.next" "$GLAEDA_BIN"
```

The first candidate install preserves the previously installed Glaeda binary as `glaeda.rollback`. Repeated candidate installs leave that copy untouched until the new enrollment is accepted.

For a Mac native-build node, prepare HMUX's normal build prerequisites and choose the operator-owned cache root:

```bash
HMUX_CACHE_ROOT=/absolute/path/to/hmux-native-cache
(
  cd "$HMUX_ROOT"
  ./scripts/setup.sh
)
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

bash "$GLAEDA_ROOT/scripts/hmux-fleet-bootstrap-macos" \
  --hmux-root "$HMUX_ROOT" \
  --glaeda "$GLAEDA_BIN" \
  --cache-root "$HMUX_CACHE_ROOT" \
  --hardware-class hmux-mac-build-large \
  --role hmux_macos_native_build \
  > "$BOOTSTRAP"
```

For a Linux CI node:

```bash
bash "$GLAEDA_ROOT/scripts/hmux-fleet-bootstrap-linux" \
  --hmux-root "$HMUX_ROOT" \
  --glaeda "$GLAEDA_BIN" \
  --hardware-class hmux-linux-ci-medium \
  --role hmux_linux_ci \
  > "$BOOTSTRAP"
```

Bootstrap is read-only. It verifies the exact HMUX checkout exposes the reviewed role profile at generation 1 and that the observed OS/architecture can run it.

## 2. Create the enrollment record

Choose an opaque node ID. Hostnames, serial numbers, private addresses, usernames, and MDM identifiers stay out of the record.

```bash
set -euo pipefail
cd "$GLAEDA_ROOT"
case "$(uname -s)" in
  Darwin) NODE_ID=hmux-mac-001 ;;
  Linux) NODE_ID=hmux-linux-001 ;;
  *) echo "unsupported host" >&2; exit 1 ;;
esac

ENROLLMENT="$FLEET_ROOT/enrollment.json"
ENROLLMENT_NEXT="$(mktemp "$FLEET_ROOT/.enrollment.XXXXXX")"
python3 scripts/hmux_fleet.py enroll "$BOOTSTRAP" \
  --node-id "$NODE_ID" \
  --scope hmux-founders \
  --generation 1 \
  > "$ENROLLMENT_NEXT"
chmod 600 "$ENROLLMENT_NEXT"
mv "$ENROLLMENT_NEXT" "$ENROLLMENT"
```

The new enrollment starts in `enrolling`. It records the role's exact HMUX profile ID/generation, the observed toolchain generation, the installed Glaeda generation, and bounded machine capability classes.

## 3. Run local acceptance and activate eligibility

Glaeda #1091 has landed the repaired `accept-local` boundary. Candidate eligibility now comes from a Glaeda-owned local attempt: Glaeda resolves the exact local HMUX commit/tree, launches the enrolled repository-owned profile under its closed child environment, captures the canonical HMUX semantic result, re-observes the same node, and emits `glaeda-hmux-fleet-acceptance/v2`.

```bash
set -euo pipefail
cd "$GLAEDA_ROOT"

case "$(uname -s)" in
  Darwin) ACCEPTANCE_ROLE=hmux_macos_native_build ;;
  Linux) ACCEPTANCE_ROLE=hmux_linux_ci ;;
  *) echo "unsupported host" >&2; exit 1 ;;
esac

ACCEPTANCE="$FLEET_ROOT/acceptance/$ACCEPTANCE_ROLE.json"
ACCEPTANCE_NEXT="$(mktemp "$FLEET_ROOT/acceptance/.$ACCEPTANCE_ROLE.XXXXXX")"

if [ "$ACCEPTANCE_ROLE" = hmux_macos_native_build ]; then
  python3 scripts/hmux_fleet.py accept-local "$ENROLLMENT" \
    --hmux-root "$HMUX_ROOT" \
    --glaeda "$GLAEDA_BIN" \
    --cache-root "$HMUX_CACHE_ROOT" \
    --role "$ACCEPTANCE_ROLE" \
    > "$ACCEPTANCE_NEXT"
else
  python3 scripts/hmux_fleet.py accept-local "$ENROLLMENT" \
    --hmux-root "$HMUX_ROOT" \
    --glaeda "$GLAEDA_BIN" \
    --role "$ACCEPTANCE_ROLE" \
    > "$ACCEPTANCE_NEXT"
fi

chmod 600 "$ACCEPTANCE_NEXT"
mv "$ACCEPTANCE_NEXT" "$ACCEPTANCE"

python3 scripts/hmux_fleet.py transition-apply "$ENROLLMENT" --to eligible \
  --acceptance "$ACCEPTANCE"

bash scripts/hmux-fleet status "$ENROLLMENT" \
  --acceptance "$ACCEPTANCE"
```

The v2 receipt binds the exact HMUX result digest/state, HMUX environment class/toolchain identity, fresh post-run bootstrap digest, Glaeda fleet-contract generation, local execution class/attempt digest, enrollment/profile/Glaeda/toolchain generations, and process settlement. Externally supplied HMUX semantic evidence can be validated, but cannot mint an accepted fleet receipt.

Both Python front doors inside `accept-local` execute through isolated interpreter mode with an explicit environment allowlist and attempt-private temporary directory. The HMUX workload profile remains the owner of commands, semantic validator, artifacts, environment class, timeout, and pass/fail result; Glaeda owns the machine-local attempt, lifecycle, and admission evidence.

`automaticDispatchAuthorized` remains false after enrollment/acceptance. Higher-level routing and fresh local physical admission still decide whether work actually starts.

After the new generation is accepted, remove only the transient bootstrap evidence and preserved one-step Glaeda rollback:

```bash
rm -f "$GLAEDA_INSTALL_ROOT/glaeda.rollback" "$BOOTSTRAP"
```

## CI and physical proof

Hosted CI validates the HMUX profile contract and Glaeda's enrollment/result-binding contract without claiming physical hardware acceptance.

The first physical proof should use one HMUX-owned host with two caller classes converging on the same machine-local lease boundary. The preferred proof remains a GitHub Actions compile request plus a direct HMUX native request, or the Linux equivalent.

Related HMUX work: #13091, #13095, #13198, #13325, #13411.
Related Glaeda work: teamleaderleo/glaeda#546, #970, #1010, #1056, #1057, #1071, #1088, #1091.
