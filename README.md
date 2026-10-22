# Cubby

Cubby turns one Windows 11 Pro PC into a shared, isolated build host for several coding agents ("bots").
Each bot gets its own cubby: a separate Linux user in WSL2 with its own home, work and cache directories,
virtual display and audio sink. The PC owner keeps the single interactive Remote Desktop session, reachable
only over Tailscale.

It was built to run iOS builds with [xtool](https://github.com/xtool-org/xtool) from Linux, but the
isolation layer works for any headless build or test agent.

## Why this layout
- Windows 11 Pro allows one interactive RDP session. Multi-session patches (RDP Wrapper, termsrv edits) are
  unsupported and break the licence, so Cubby does not use them.
- Agents work headless, so isolation happens inside WSL2: one Linux user per bot means separate logins and
  config (`~/.config`, CLI auth), separate caches, and no shared screen, input or sound.
- Heavier option, not included: one Hyper-V VM per bot.

## What each bot gets
| item | value (bot `NAME`, n-th in list) |
|---|---|
| Linux user | `bot-NAME` (no password; entry via `wsl -u`) |
| work dir | `/srv/builds/NAME/work` (mode 700) |
| cache | `/srv/builds/NAME/cache` |
| display | Xvfb `:(10+n)`, TCP disabled |
| audio | PulseAudio null sink `bot_NAME` |

Shared read-only SDK directory: `/srv/shared/sdk` (group `buildbots`).

## Setup
1. **Windows** (elevated PowerShell): `windows\enable-rdp-tailscale.ps1` enables RDP with NLA and allows it
   only from the Tailscale range `100.64.0.0/10`.
2. Optional: copy `windows/wslconfig.example` to `%UserProfile%\.wslconfig`, then `wsl --shutdown`.
3. **WSL2 Ubuntu 24.04**: copy `bots.example` to `bots.conf`, list your bot names, then
   `wsl/setup-build-host.sh`. Preview first with `DRY_RUN=1 wsl/setup-build-host.sh`.
4. **iOS SDK** (only for xtool): do not download Xcode.xip. On a Mac, archive the needed parts of
   `/Applications/Xcode.app`, copy them to `/srv/shared/sdk`, then run once:
   `xtool sdk install /srv/shared/sdk/Xcode.app --slim`.
   For signing, use `xtool auth` with an App Store Connect API key. No Apple ID password is stored.

## Apple 개발자 팀 (2026-10-22~)
iOS·macOS 빌드 서명, TestFlight, App Store 출시는 모두 조직 **207 Studio (Team ID `H32W23F7UW`)**로 한다.
- Xcode/xcodebuild: `DEVELOPMENT_TEAM = H32W23F7UW`, `CODE_SIGN_STYLE = Automatic`.
- xtool: `xtool auth`에 쓰는 App Store Connect API 키는 207 Studio 팀에서 발급한 것만 쓴다. 키 파일·Issuer ID 값은 저장소에 넣지 않는다.
- TestFlight 업로드와 App Store 제출은 Mac에서 207 Studio 팀으로 한다. 예전 개인 팀으로 서명한 빌드는 올리지 않는다.

## Usage
```
wsl -d Ubuntu-24.04 -u bot-NAME
cd "$WORK"
swb            # swift build with this bot's own cache and scratch path
```

## Limits
iOS Simulator, full xcodeproj builds, actool/xcstrings/Core ML compilation and App Store upload still need a
Mac. The per-bot Xvfb displays are for Linux GUI and screenshot tools, not iOS simulators.

## Security model
- RDP: NLA required, firewall allows only the Tailscale CGNAT range. Your tailnet ACLs are the outer boundary.
- Bots: no passwords, no sudo, home and work dirs not readable by other bots. Isolation is Linux user
  separation inside one WSL2 VM, not a VM boundary; do not run mutually untrusted code side by side.
- Secrets: the scripts create none and store none. Each bot logs in to its own tools under its own home.
- Bot names are validated (`^[a-z][a-z0-9-]{0,30}$`) before they reach `useradd` or systemd unit files.

## Development
`tests/run.sh` runs the tests with plain bash (no installs). CI also runs ShellCheck.
See [AGENTS.md](AGENTS.md) if you are an agent working in this repo.

## License
MIT
