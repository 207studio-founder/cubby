#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # assertions are eval'd strings
# Plain-bash tests: no installs needed. Run: tests/run.sh
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/wsl/lib.sh"; set +e
fail=0; pass=0
ok() { if eval "$2"; then pass=$((pass+1)); else echo "FAIL: $1"; fail=$((fail+1)); fi; }

ok "valid name"          'cubby_validate_name builder-a'
ok "rejects uppercase"   '! cubby_validate_name Builder'
ok "rejects injection"   '! cubby_validate_name "a;rm"'
ok "rejects leading digit" '! cubby_validate_name 1bot'

tmp=$(mktemp); printf '# c\nalpha\n\n beta # x\n' > "$tmp"
ok "reads bots file"     '[ "$(cubby_read_bots "$tmp" | tr "\n" " ")" = "alpha beta " ]'
ok "example file valid"  'for b in $(cubby_read_bots "$root/bots.example"); do cubby_validate_name "$b" || exit 1; done'

env_out=$(cubby_env alpha 12)
ok "env display"         'grep -qx "export DISPLAY=:12" <<<"$env_out"'
ok "env isolated work"   'grep -qx "export WORK=/srv/builds/alpha/work" <<<"$env_out"'
ok "env alias escaped"   'grep -q "\$SWIFTPM_CACHE" <<<"$env_out"'
ok "display unit user"   'cubby_display_unit alpha 12 | grep -qx "User=bot-alpha"'
ok "xvfb no tcp"         'cubby_display_unit alpha 12 | grep -q "Xvfb :12 .*-nolisten tcp"'
ok "audio own sink"      'cubby_audio_unit alpha | grep -q "sink_name=bot_alpha"'

dry=$(BOTS="a b" DRY_RUN=1 bash "$root/wsl/setup-build-host.sh")
ok "dry run numbering"   'grep -q "bot-a DISPLAY=:10" <<<"$dry" && grep -q "bot-b DISPLAY=:11" <<<"$dry"'
ok "dry run rejects bad" '! BOTS="Bad" DRY_RUN=1 bash "$root/wsl/setup-build-host.sh" 2>/dev/null'
ok "ps1 tailnet-only"    'grep -q "RemoteAddress 100.64.0.0/10" "$root/windows/enable-rdp-tailscale.ps1"'
ok "no passwords set"    '! grep -rqE "chpasswd|passwd " "$root/wsl"'

rm -f "$tmp"
echo "$pass passed, $fail failed"; [ "$fail" -eq 0 ]
