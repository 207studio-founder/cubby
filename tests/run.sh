#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # assertions are eval'd strings
# Plain-bash tests: no installs needed. Run: tests/run.sh
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/wsl/lib.sh"; set +e
fail=0; pass=0
ok() { if eval "$2"; then pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }

ok "valid name"          'tray_validate_name builder-a'
ok "rejects uppercase"   '! tray_validate_name Builder'
ok "rejects injection"   '! tray_validate_name "a;rm"'
ok "rejects leading digit" '! tray_validate_name 1bot'

tmp=$(mktemp); printf '# c\nalpha\n\n beta # x\n' > "$tmp"
ok "reads bots file"     '[ "$(tray_read_bots "$tmp" | tr "\n" " ")" = "alpha beta " ]'
ok "example file valid"  'for b in $(tray_read_bots "$root/bots.example"); do tray_validate_name "$b" || exit 1; done'

env_out=$(tray_env alpha 12)
ok "env display"         'grep -qx "export DISPLAY=:12" <<<"$env_out"'
ok "env isolated work"   'grep -qx "export WORK=/srv/builds/alpha/work" <<<"$env_out"'
ok "env alias escaped"   'grep -q "\$SWIFTPM_CACHE" <<<"$env_out"'
ok "env Xauthority"      'grep -Fqx "export XAUTHORITY=/srv/builds/alpha/cache/Xauthority" <<<"$env_out"'
ok "env runtime dir"     'grep -Fqx "export XDG_RUNTIME_DIR=/srv/builds/alpha/cache/run" <<<"$env_out"'
ok "env PulseAudio server" 'grep -Fqx "export PULSE_SERVER=unix:/srv/builds/alpha/cache/run/pulse/native" <<<"$env_out"'
ok "env disables Wayland" 'grep -Fqx "unset WAYLAND_DISPLAY" <<<"$env_out"'
snap=$(tray_snapshot_cmd alpha 12 /srv/builds/alpha/work/s.png)
ok "snapshot own display" 'grep -Fqx "DISPLAY=:12 XAUTHORITY=/srv/builds/alpha/cache/Xauthority import -window root /srv/builds/alpha/work/s.png" <<<"$snap"'
ok "snapshot rejects other room" '! tray_snapshot_cmd alpha 12 /srv/builds/beta/s.png'
ok "snapshot rejects traversal" '! tray_snapshot_cmd alpha 12 /srv/builds/alpha/../beta/s.png'
ok "snapshot rejects injection" '! tray_snapshot_cmd alpha 12 "/srv/builds/alpha/a;rm.png"'
ok "snapshot rejects bad display" '! tray_snapshot_cmd alpha x1 /srv/builds/alpha/s.png'
ok "display unit user"   'tray_display_unit alpha 12 | grep -qx "User=bot-alpha"'
ok "xvfb no tcp"         'tray_display_unit alpha 12 | grep -q "Xvfb :12 .*-nolisten tcp"'
ok "xvfb Xauthority"     'tray_display_unit alpha 12 | grep -q "Xvfb :12 .*-auth /srv/builds/alpha/cache/Xauthority$"'
ok "xvfb no local"       'tray_display_unit alpha 12 | grep -q "Xvfb :12 .*-nolisten local"'
ok "display Xauthority env" 'tray_display_unit alpha 12 | grep -Fqx "Environment=XAUTHORITY=/srv/builds/alpha/cache/Xauthority"'
display_pre_start=$(cat <<'COMMAND'
ExecStartPre=/bin/sh -c 'test -s /srv/builds/alpha/cache/Xauthority || xauth -f /srv/builds/alpha/cache/Xauthority add :12 . "$$(mcookie)"'
COMMAND
)
ok "display creates cookie with systemd escaping" 'tray_display_unit alpha 12 | grep -Fqx "$display_pre_start"'
ok "audio own sink"      'tray_audio_unit alpha | grep -q "sink_name=bot_alpha"'
ok "audio authenticated socket" 'tray_audio_unit alpha | grep -Fq -- "-L \"module-native-protocol-unix auth-anonymous=0\""'
ok "audio private runtime dir" 'tray_audio_unit alpha | grep -Fqx "ExecStartPre=/bin/mkdir -p -m 700 /srv/builds/alpha/cache/run"'

wsl_conf=$(tray_wsl_conf)
ok "wsl enables systemd" 'grep -A1 -Fx "[boot]" <<<"$wsl_conf" | grep -Fqx "systemd=true"'
ok "wsl disables interop" 'grep -A2 -Fx "[interop]" <<<"$wsl_conf" | grep -Fqx "enabled=false"'
ok "wsl disables Windows PATH" 'grep -A2 -Fx "[interop]" <<<"$wsl_conf" | grep -Fqx "appendWindowsPath=false"'
ok "wslconfig disables WSLg" 'grep -A4 -Fx "[wsl2]" "$root/windows/wslconfig.example" | grep -Fqx "guiApplications=false"'
ok "cubby wrappers still work" 'declare -F tray_validate_name tray_read_bots tray_env tray_display_unit tray_audio_unit >/dev/null &&
  cubby_validate_name builder-a && ! cubby_validate_name Builder &&
  [ "$(cubby_read_bots "$tmp")" = "$(tray_read_bots "$tmp")" ] &&
  [ "$(cubby_env alpha 12)" = "$(tray_env alpha 12)" ] &&
  [ "$(cubby_display_unit alpha 12)" = "$(tray_display_unit alpha 12)" ] &&
  [ "$(cubby_audio_unit alpha)" = "$(tray_audio_unit alpha)" ]'

dry=$(BOTS="a b" DRY_RUN=1 bash "$root/wsl/setup-build-host.sh")
ok "dry run numbering"   'grep -q "bot-a DISPLAY=:10" <<<"$dry" && grep -q "bot-b DISPLAY=:11" <<<"$dry"'
ok "dry run WSLg requirement" 'grep -Fqx "wslg: guiApplications=false required" <<<"$dry"'
ok "dry run rejects bad" '! BOTS="Bad" DRY_RUN=1 bash "$root/wsl/setup-build-host.sh" 2>/dev/null'
ok "ps1 tailnet-only"    'grep -q "RemoteAddress 100.64.0.0/10" "$root/windows/enable-rdp-tailscale.ps1"'
ok "no passwords set"    '! grep -rqE "chpasswd|passwd " "$root/wsl"'

rm -f "$tmp"
echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
