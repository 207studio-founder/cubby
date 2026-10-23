#!/usr/bin/env bash
# Run inside WSL2 Ubuntu 24.04 as a sudo-capable user. Idempotent.
# Installs xtool and creates one isolated Linux user per bot, each with its own HOME,
# work and cache dirs, Xvfb display and PulseAudio null sink.
#
#   BOTS="builder-a reviewer" wsl/setup-build-host.sh     # or put names in bots.conf
#   DRY_RUN=1 wsl/setup-build-host.sh                     # print the plan, change nothing
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=wsl/lib.sh
. "$here/lib.sh"
XTOOL_VER="${XTOOL_VER:-1.22.2}"
FIRST_DISPLAY="${FIRST_DISPLAY:-10}"
if [ -z "${BOTS:-}" ]; then
  conf="${BOTS_FILE:-$here/../bots.conf}"
  [ -f "$conf" ] || { echo "No BOTS set and $conf missing (see bots.example)" >&2; exit 2; }
  BOTS="$(tray_read_bots "$conf" | tr '\n' ' ')"
fi
for b in $BOTS; do tray_validate_name "$b" || { echo "invalid bot name: $b" >&2; exit 2; }; done

if [ -n "${DRY_RUN:-}" ]; then
  echo "wslg: guiApplications=false required"
  n=$FIRST_DISPLAY
  for b in $BOTS; do echo "bot-$b DISPLAY=:$n sink=bot_$b work=/srv/builds/$b/work"; n=$((n+1)); done
  exit 0
fi

if [ -L /tmp/.X11-unix ]; then
  echo 'WSLg symlink at /tmp/.X11-unix: set guiApplications=false under [wsl2] in %UserProfile%\.wslconfig, run wsl --shutdown from Windows, then retry.' >&2
  exit 3
fi
sudo install -d -m 1777 -o root -g root /tmp/.X11-unix

if ! tray_wsl_conf | sudo cmp -s - /etc/wsl.conf; then
  if [ -e /etc/wsl.conf ]; then
    sudo cp -p /etc/wsl.conf /etc/wsl.conf.bak
  fi
  tray_wsl_conf | sudo tee /etc/wsl.conf >/dev/null
  echo 'Updated /etc/wsl.conf; run wsl --shutdown from Windows to apply changes.'
fi

sudo apt-get update -qq
sudo apt-get install -y -qq xvfb xauth pulseaudio pulseaudio-utils imagemagick libfuse2t64 curl git unzip >/dev/null
if ! [ -x /usr/local/bin/xtool ] || ! /usr/local/bin/xtool --version 2>/dev/null | grep -q "$XTOOL_VER"; then
  curl -fsSL -o /tmp/xtool.AppImage "https://github.com/xtool-org/xtool/releases/download/${XTOOL_VER}/xtool-x86_64.AppImage"
  sudo install -m755 /tmp/xtool.AppImage /usr/local/bin/xtool
fi
sudo groupadd -f buildbots
sudo mkdir -p /srv/builds /srv/shared/sdk && sudo chgrp buildbots /srv/shared/sdk && sudo chmod 2775 /srv/shared/sdk
n=$FIRST_DISPLAY
for b in $BOTS; do
  u="bot-$b"
  id "$u" &>/dev/null || sudo useradd -m -s /bin/bash -G buildbots "$u"   # no password: entry only via `wsl -u`
  sudo install -d -o "$u" -g "$u" -m 700 "/srv/builds/$b" "/srv/builds/$b/work" "/srv/builds/$b/cache"
  tray_env "$b" "$n" | sudo tee "/home/$u/.bot-env" >/dev/null
  sudo grep -q bot-env "/home/$u/.bashrc" || echo '. ~/.bot-env' | sudo tee -a "/home/$u/.bashrc" >/dev/null
  sudo chown "$u:$u" "/home/$u/.bot-env"
  tray_display_unit "$b" "$n" | sudo tee "/etc/systemd/system/bot-display@$b.service" >/dev/null
  tray_audio_unit "$b" | sudo tee "/etc/systemd/system/bot-audio@$b.service" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable --now "bot-display@$b" "bot-audio@$b" >/dev/null
  n=$((n+1))
done
echo "xtool: $(xtool --version 2>&1 | head -1)"
echo "Next: copy a slim Xcode.app from a Mac to /srv/shared/sdk, then: xtool sdk install /srv/shared/sdk/Xcode.app --slim"
