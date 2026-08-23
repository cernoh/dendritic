---
name: windows-openssh-key-auth
description: Enable Windows OpenSSH and configure passphrase-free public-key authentication
---

## Procedure

Run PowerShell as Administrator on the Windows target:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

Install the client public key with an explicit key path:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub zoiny@HOST
```

If `ssh-copy-id` cannot create the Windows files, create `C:\Users\zoiny\.ssh\authorized_keys` manually and apply restrictive ACLs:

```powershell
icacls C:\Users\zoiny\.ssh\authorized_keys /inheritance:r /grant "zoiny:F" /grant "SYSTEM:F" /grant "Administrators:F"
```

Verify with `ssh zoiny@HOST`. Windows OpenSSH requires strict authorized_keys permissions; its default shell is usually `cmd.exe`.
