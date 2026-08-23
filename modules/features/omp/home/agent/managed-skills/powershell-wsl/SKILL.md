---
name: powershell-wsl
description: Reference for running PowerShell commands from WSL using powershell.exe.
---

# PowerShell through WSL

Run Windows PowerShell from a WSL Linux shell using `powershell.exe` (Windows PowerShell 5.1). Use `pwsh.exe` for PowerShell 7 if it is installed.

## Basic usage

Run a PowerShell command:

```bash
powershell.exe -Command "Get-Date"
# or short form:
powershell.exe -c "Get-Date"
```

Run a PowerShell script file:

```bash
powershell.exe -File "C:\\Users\\Me\\script.ps1"
```

Open the current WSL directory in Windows File Explorer via PowerShell:

```bash
powershell.exe /c start .
```

## Path translation

WSL paths must be translated to Windows paths for PowerShell. Use `wslpath`:

```bash
powershell.exe -c "Get-ChildItem '$(wslpath -w .)'"
powershell.exe -c "Get-Content '$(wslpath -w /home/user/file.txt)'"
wslpath -u 'C:\Users\Me'
```

- `-w` — WSL path → Windows path
- `-u` — Windows path → WSL path
- `-m` — Windows path with forward slashes

## Mixing Linux and PowerShell

```bash
ls -la | powershell.exe -c "$input | Select-String foo"
powershell.exe -c "Get-Process" | grep powershell
```

`$input` is PowerShell’s automatic pipeline variable.

## PowerShell 7 vs Windows PowerShell

- `powershell.exe` — Windows PowerShell 5.1.
- `pwsh.exe` — PowerShell 7, if installed.

Prefer `pwsh.exe` for cross-platform cmdlets; use `powershell.exe` when 5.1-only modules are required.

## Environment variables

```bash
export MY_VAR="value"
export WSLENV="MY_VAR"
powershell.exe -c "Write-Host \$env:MY_VAR"
```

For paths, use `WSLENV="MY_PATH/p"`.

## Quoting rules

PowerShell commands are passed as one argument to `-Command`. Bash expands `$variables` inside double-quoted arguments before PowerShell receives them. This can silently remove PowerShell variables and cause parse errors, such as `An expression was expected after '('`.

**Preferred for multi-variable commands:** wrap the entire PowerShell command in single quotes on the Bash side:

```bash
powershell.exe -NoProfile -Command '$u = [Security.Principal.WindowsIdentity]::GetCurrent(); $u.Name'
```

Alternatively, escape each PowerShell `$` as `\$` when the outer Bash string must use double quotes:

```bash
powershell.exe -NoProfile -Command "Write-Output \$env:USERNAME"
```

Use single quotes inside PowerShell strings where possible. Escape embedded double quotes when using a Bash double-quoted command.

## SSH into Windows with keys

Windows OpenSSH accepts keys with `-i`:

```bash
ssh -i ~/.ssh/id_ed25519 WindowsUsername@windows-host
```

For a non-administrator account, put the public key in:

```text
C:\Users\\WindowsUsername\\.ssh\\authorized_keys
```

For administrator accounts, use:

```text
C:\\ProgramData\\ssh\\administrators_authorized_keys
```

Set restrictive ACLs on the administrator key file:

```powershell
icacls C:\\ProgramData\\ssh\\administrators_authorized_keys /inheritance:r
icacls C:\\ProgramData\\ssh\\administrators_authorized_keys /grant "SYSTEM:F" "Administrators:F"
```

Check the SSH service:

```powershell
Get-Service sshd
Start-Service sshd
Set-Service sshd -StartupType Automatic
```

## Troubleshooting

- `powershell.exe: command not found` — WSL interop may be disabled; restart WSL or re-enable interop.
- Path errors — translate WSL paths with `wslpath -w`.
- Permissions — Windows executables launched from WSL run as the active Windows user.
- Key authentication failing for an administrator — verify the key is in `C:\\ProgramData\\ssh\\administrators_authorized_keys` and its ACLs are restricted.

## Docs

- https://learn.microsoft.com/en-us/windows/wsl/filesystems
- https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
