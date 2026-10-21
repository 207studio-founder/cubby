# Run in an ELEVATED PowerShell. Idempotent.
# Enables Remote Desktop with NLA, restricts inbound RDP to the Tailscale CGNAT range
# (100.64.0.0/10) and sets the service to start on boot.
#Requires -RunAsAdministrator
$ts = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
Set-ItemProperty $ts fDenyTSConnections 0
Set-ItemProperty "$ts\WinStations\RDP-Tcp" UserAuthentication 1
Set-Service TermService -StartupType Automatic
Start-Service TermService
# Disable the built-in RDP rules (group names are localized) and add a Tailscale-only rule.
Get-NetFirewallRule | Where-Object { $_.Name -like 'RemoteDesktop-*' } | Disable-NetFirewallRule
if (-not (Get-NetFirewallRule -Name 'RDP-Tailscale-Only' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'RDP-Tailscale-Only' -DisplayName 'RDP via Tailscale only' -Direction Inbound `
    -Protocol TCP -LocalPort 3389 -RemoteAddress 100.64.0.0/10 -Action Allow | Out-Null
}
Get-Service TermService | Format-Table Name,Status,StartType
Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue | Format-Table LocalAddress,LocalPort
Write-Host "Connect to <this PC's Tailscale name or IP>:3389 from a device on the same tailnet."
