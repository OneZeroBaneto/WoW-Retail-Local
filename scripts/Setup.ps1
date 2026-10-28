#Requires -Version 7.4
param([string]$ClientRoot,[switch]$NorthshireWarrior,[string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName))
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Windows.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Process.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Readiness.psm1" -DisableNameChecking
Assert-Windows
$pwsh=Join-Path $PSHOME 'pwsh.exe'
function Run-Step([string]$Action){Invoke-Native $pwsh @('-NoProfile','-File',"$PSScriptRoot/Manage.ps1",'-Root',$Root,'-Action',$Action)}
if(Read-SupervisorState $Root){throw 'Stop this server before running setup.'}
Run-Step 'Configure'
$p=Read-Profile $Root;$s=Read-LocalSettings $Root
if(!$ClientRoot -and !(Test-Path (Join-Path $s.clientRoot $p.client.relativeExe))){$ClientRoot=Read-Host 'WoW main directory containing .build.info and _retail_'}
if($ClientRoot) {
    Assert-ConfigPath $ClientRoot
    $guard=[IO.File]::Open("$Root/runtime/instance.lock",[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{$s.clientRoot=[IO.Path]::GetFullPath($ClientRoot);Write-JsonFile "$Root/local/settings.json" $s}finally{$guard.Dispose()}
    Run-Step 'Configure'
}
$clientVersion=Get-ClientExecutableVersion (Join-Path $s.clientRoot $p.client.relativeExe)
Assert-ClientVersion $p $clientVersion
$null=Read-CascProduct $s.clientRoot $p.client.version
foreach($name in @('mysqld','mysql','mysqladmin')){Require-File (Get-MySQLTool $s $name)}
Require-File (Join-Path $s.opensslRoot 'bin/openssl.exe');Require-File $s.sevenZip
if(!(Get-Command git -ErrorAction SilentlyContinue)){throw 'Install Git for Windows first.'}
$stages=@(
    @{name='Source';ready={Assert-SourceReady "$Root/vendor/core" $p.core.commit (Get-ConsolePatch $Root $p);$true};run={Run-Step 'Source'}},
    @{name='Build';ready={Assert-BuildReady $Root $p;$true};run={Run-Step 'Build'}},
    @{name='DatabaseFiles';ready={Assert-FileHash "$Root/downloads/tdb.7z" $p.database.sha256;foreach($f in $p.database.files){Require-File "$Root/runtime/$f"};$true};run={Run-Step 'DatabaseFiles'}},
    @{name='Extract';ready={Assert-DataReady $Root $p;$true};run={Run-Step 'Extract'}},
    @{name='Database';ready={$d=Get-Content "$Root/runtime/database.json" -Raw | ConvertFrom-Json;$d.coreCommit -eq $p.core.commit -and $d.clientVersion -eq $p.client.version};run={Run-Step 'Database'}},
    @{name='Certificates';ready={(Test-Path "$Root/runtime/certs/server.crt") -and (Test-Path "$Root/runtime/certs/server.key")};run={Run-Step 'Certificates'}}
)
Invoke-PreparationStages $p $clientVersion $stages
if($NorthshireWarrior){Invoke-Native $pwsh @('-NoProfile','-File',"$PSScriptRoot/Starter.ps1",'-Root',$Root)}
Invoke-Native $pwsh @('-NoProfile','-File',"$PSScriptRoot/Audit.ps1",'-Root',$Root)
Write-Host 'Preparation finished. Use Start.bat, then Account.bat, then Client.bat. Follow docs/FIRST-PLAY.md for the real game test.'
