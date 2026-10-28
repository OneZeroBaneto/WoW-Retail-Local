#Requires -Version 7.4
param([switch]$Restore,[switch]$Launch,[string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName))
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Windows.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Readiness.psm1" -DisableNameChecking
Assert-Windows
$p=Read-Profile $Root;$s=Read-LocalSettings $Root
if($p.edition -ne 'retail'){throw 'This launcher setup is for Retail.'}
if(@(Get-Process -Name 'Wow','WowB','Burralis Game Launcher' -ErrorAction SilentlyContinue).Count){throw 'Close WoW and the custom launcher before changing the client portal.'}
$exe=Join-Path $s.clientRoot $p.client.relativeExe
$folder=Split-Path $exe -Parent
$config=Join-Path $folder 'WTF/Config.wtf';$backup="$Root/local/portal-backup"
if($Restore){Restore-ClientPortal $config $backup;Write-Host 'Original client settings restored.';exit 0}
Require-File $exe
Assert-ClientVersion $p (Get-ClientExecutableVersion $exe)
$null=Read-CascProduct $s.clientRoot $p.client.version
if(![System.Runtime.Intrinsics.X86.Avx2]::IsSupported -or ![System.Runtime.Intrinsics.X86.Aes]::IsSupported){throw 'This launcher requires AVX2 and AES-NI support.'}
$launcher=Join-Path $folder 'Burralis Game Launcher.exe'
Require-File $launcher
Assert-FileHash $launcher 'b5359a972f760905f572aafc4066d945f6382cec2a521d555dd58d2861ef7c1c'
if((Get-AuthenticodeSignature $launcher).Status -ne 'Valid'){throw 'Launcher digital signature is not valid.'}
Set-LocalClientPortal $config $backup
Write-Host 'Client portal points to 127.0.0.1; original settings saved. Run Restore-Client.bat before returning to official Retail.'
if($Launch){Start-Process -FilePath $launcher -WorkingDirectory $folder;Write-Host 'Launcher opened. Verify login and world entry in the client.'}
