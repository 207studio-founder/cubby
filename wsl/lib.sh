#!/usr/bin/env bash
# Pure render functions used by setup-build-host.sh. No side effects; covered by tests/.
set -euo pipefail

tray_validate_name() { [[ "$1" =~ ^[a-z][a-z0-9-]{0,30}$ ]]; }

tray_read_bots() { # $1 = file; prints names, skips blanks and comments
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | awk 'NF'
}

tray_env() { # bot display_number
  local b="$1" n="$2"
  cat <<ENV
export BOT=$b
export WORK=/srv/builds/$b/work
export XDG_CACHE_HOME=/srv/builds/$b/cache
export XDG_RUNTIME_DIR=/srv/builds/$b/cache/run
export SWIFTPM_CACHE=/srv/builds/$b/cache/swiftpm
export DISPLAY=:$n
export XAUTHORITY=/srv/builds/$b/cache/Xauthority
export PULSE_SINK=bot_$b
export PULSE_SERVER=unix:/srv/builds/$b/cache/run/pulse/native
unset WAYLAND_DISPLAY
alias swb='swift build --cache-path \$SWIFTPM_CACHE --scratch-path \$WORK/.build'
ENV
}

tray_display_unit() { # bot display_number
  local b="$1" n="$2"
  cat <<UNIT
[Unit]
Description=Kiwi Tray Xvfb :$n for $b
[Service]
User=bot-$b
Environment=XAUTHORITY=/srv/builds/$b/cache/Xauthority
ExecStartPre=/bin/sh -c 'test -s /srv/builds/$b/cache/Xauthority || xauth -f /srv/builds/$b/cache/Xauthority add :$n . "\$\$(mcookie)"'
ExecStart=/usr/bin/Xvfb :$n -screen 0 1920x1080x24 -nolisten tcp -nolisten local -auth /srv/builds/$b/cache/Xauthority
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
}

tray_audio_unit() { # bot
  local b="$1"
  cat <<UNIT
[Unit]
Description=Kiwi Tray PulseAudio null sink for $b
[Service]
User=bot-$b
Environment=XDG_RUNTIME_DIR=/srv/builds/$b/cache/run
ExecStartPre=/bin/mkdir -p -m 700 /srv/builds/$b/cache/run
ExecStart=/usr/bin/pulseaudio --daemonize=no --exit-idle-time=-1 -n -L "module-null-sink sink_name=bot_$b" -L "module-native-protocol-unix auth-anonymous=0"
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
}

tray_wsl_conf() {
  cat <<'CONF'
[boot]
systemd=true
[interop]
enabled=false
appendWindowsPath=false
CONF
}

tray_snapshot_cmd() { # bot display_number out.png -> prints a screen-free capture command for that bot's own Xvfb
  local b="$1" n="$2" out="$3"
  tray_validate_name "$b" || return 1
  [[ "$n" =~ ^[0-9]{1,3}$ ]] || return 1
  [[ "$out" =~ ^/srv/builds/$b/[A-Za-z0-9._/-]+\.png$ && "$out" != *..* ]] || return 1
  printf 'DISPLAY=:%s XAUTHORITY=/srv/builds/%s/cache/Xauthority import -window root %s\n' "$n" "$b" "$out"
}

cubby_validate_name() { tray_validate_name "$@"; }
cubby_read_bots() { tray_read_bots "$@"; }
cubby_env() { tray_env "$@"; }
cubby_display_unit() { tray_display_unit "$@"; }
cubby_audio_unit() { tray_audio_unit "$@"; }
