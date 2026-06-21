# SSH into Windows VMs — including offline Windows 7, plus RDP over SSH

SSH turns a Windows VM (or any Windows box) into something you can script, automate, and
reach headlessly — no console window, no clicking through the VMware/Hyper-V UI. This covers
three things:

1. Enabling the OpenSSH **server** on modern Windows (10/11/Server).
2. Doing it **offline**, on machines that can't use `Add-WindowsCapability` — notably
   **Windows 7**.
3. Tunneling **RDP over SSH** so you get the full desktop even when only SSH is reachable.

All server commands run from an **elevated** PowerShell (Run as administrator).

---

## 1. Modern Windows (10 / 11 / Server)

OpenSSH Server ships as an optional capability:

```powershell
# Install + start + enable at boot
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# Firewall (the capability usually adds this; create it if missing)
if (-not (Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
```

### Make PowerShell the default shell (recommended)

By default you land in `cmd`. Point the default shell at PowerShell so your SSH session is
a real PowerShell:

```powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force
```

(Use the `pwsh.exe` path instead if you have PowerShell 7+ installed.)

---

## 2. Offline / Windows 7 (no internet, no capability store)

`Add-WindowsCapability` doesn't exist on Windows 7, and these machines are often air-gapped.
Use the official **Win32-OpenSSH** release instead — a self-contained zip you stage once.

> ⚠️ **Windows 7 is end-of-life.** Keep it off the public internet; use this only on
> isolated/lab networks.

**On a machine with internet**, download the matching release zip from the Microsoft
`PowerShell/Win32-OpenSSH` project — `OpenSSH-Win64-*.zip` for 64-bit guests,
`OpenSSH-Win32-*.zip` for 32-bit — and copy it into the guest (shared folder or USB).

**Inside the guest (elevated PowerShell):**

```powershell
# 1. Extract to a stable location
Expand-Archive .\OpenSSH-Win64-vX.Y.Z.zip -DestinationPath "C:\Program Files\OpenSSH"
Set-Location "C:\Program Files\OpenSSH\OpenSSH-Win64"

# 2. Install the sshd + ssh-agent services
powershell -ExecutionPolicy Bypass -File .\install-sshd.ps1

# 3. Open the firewall for port 22
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

# 4. Start + enable at boot
Set-Service sshd -StartupType Automatic
Start-Service sshd
```

Set the default shell exactly as in section 1 (the
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` path is present on Windows 7 too).

> On very old guests `New-NetFirewallRule` may be unavailable — fall back to
> `netsh advfirewall firewall add rule name=sshd dir=in action=allow protocol=TCP localport=22`.

---

## 3. Find the guest and connect

Get the guest's IP from inside it:

```powershell
ipconfig | Select-String IPv4
```

In typical VMware setups a guest is reachable on its **NAT** (`192.168.x.x`) or
**host-only/internal** address without any port-forwarding. Then from your machine:

```bash
ssh user@<guest-ip>
```

---

## 4. RDP over SSH (full desktop through the tunnel)

When only SSH is exposed — or you just want RDP encrypted and firewall-friendly — forward a
local port to the guest's RDP port over the SSH connection:

```bash
# Local 13389  ->  guest's 3389, through SSH
ssh -L 13389:localhost:3389 user@<guest-ip>
```

Leave that session open, then point your RDP client at the local end:

```powershell
mstsc /v:localhost:13389
```

You're now RDP'd into the guest, tunneled through SSH. The same pattern forwards any guest
service (e.g. a database or web port) to your machine.

---

## 5. Harden it (do this before relying on it)

- **Use key auth.** Add your public key, then disable passwords. For accounts in the
  Administrators group, Windows OpenSSH reads
  `C:\ProgramData\ssh\administrators_authorized_keys` (strict ACLs: owner SYSTEM +
  Administrators only). Non-admin users use `~\.ssh\authorized_keys`.
- In `C:\ProgramData\ssh\sshd_config` set `PasswordAuthentication no` after keys work, then
  `Restart-Service sshd`.
- **Never port-forward the guest's SSH to the public internet**, especially on legacy OSes.

## Teardown

```powershell
Stop-Service sshd
Set-Service sshd -StartupType Disabled
# modern Windows: Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
# offline install: run .\uninstall-sshd.ps1 from the OpenSSH folder
```
