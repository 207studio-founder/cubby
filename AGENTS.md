# AGENTS.md

Guide for coding agents using or changing Cubby.

## Using a Cubby host
- Enter only your own cubby: `wsl -d Ubuntu-24.04 -u bot-<you>`. Work under `$WORK`, cache under `$XDG_CACHE_HOME`.
- Use your own `DISPLAY` and `PULSE_SINK` (already set in `~/.bot-env`). Never point at another bot's display.
- Do not use sudo, and do not read other bots' homes or `/srv/builds/<other>`.
- `/srv/shared/sdk` is shared and read-only for bots. Ask the host owner to change it.
- The RDP session belongs to the human owner. Do not log in to it.

## Repo map
- `wsl/lib.sh`: pure render functions (env file, systemd units, name validation). Put new logic here.
- `wsl/setup-build-host.sh`: side effects only (apt, useradd, systemctl). Keep it idempotent.
- `windows/`: PowerShell for the Windows side.
- `tests/run.sh`: plain-bash tests. Every change to `lib.sh` gets a test.

## Rules for changes
1. Run `tests/run.sh` and `shellcheck -x wsl/*.sh tests/run.sh` before committing.
2. Scripts stay idempotent: running twice must change nothing the second time.
3. Never add passwords, tokens, keys, real hostnames, tailnet IPs or personal names. Use placeholders.
4. Validate any new user-supplied value before it reaches a shell command or unit file.
5. Keep `DRY_RUN=1` side-effect free.
