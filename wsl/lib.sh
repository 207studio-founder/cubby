#!/usr/bin/env bash
# Pure render functions used by setup-build-host.sh. No side effects; covered by tests/.
set -euo pipefail

cubby_validate_name() { [[ "$1" =~ ^[a-z][a-z0-9-]{0,30}$ ]]; }

cubby_read_bots() { # $1 = file; prints names, skips blanks and comments
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | awk 'NF'
}

cubby_env() { # bot display_number
  local b="$1" n="$2"
  cat <<ENV
export BOT=$b
export WORK=/srv/builds/$b/work
export XDG_CACHE_HOME=/srv/builds/$b/cache
export SWIFTPM_CACHE=/srv/builds/$b/cache/swiftpm
export DISPLAY=:$n
export PULSE_SINK=bot_$b
alias swb='swift build --cache-path \$SWIFTPM_CACHE --scratch-path \$WORK/.build'
ENV
}

cubby_display_unit() { # bot display_number
  local b="$1" n="$2"
  cat <<UNIT
[Unit]
Description=Cubby Xvfb :$n for $b
[Service]
User=bot-$b
ExecStart=/usr/bin/Xvfb :$n -screen 0 1920x1080x24 -nolisten tcp
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
}

cubby_audio_unit() { # bot
  local b="$1"
  cat <<UNIT
[Unit]
Description=Cubby PulseAudio null sink for $b
[Service]
User=bot-$b
Environment=XDG_RUNTIME_DIR=/srv/builds/$b/cache/run
ExecStartPre=/bin/mkdir -p /srv/builds/$b/cache/run
ExecStart=/usr/bin/pulseaudio --daemonize=no --exit-idle-time=-1 -n -L "module-null-sink sink_name=bot_$b" -L module-native-protocol-unix
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
}
