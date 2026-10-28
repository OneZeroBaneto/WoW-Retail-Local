#Requires -Version 7.4
param([string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName))
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Windows.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Process.psm1" -DisableNameChecking
$p=Read-Profile $Root
$report=[ordered]@{createdAt=[DateTime]::UtcNow.ToString('o');edition=$p.edition;expectedClient=$p.client.version;coreCommit=$p.core.commit;powerShell=$PSVersionTable.PSVersion.ToString();windows=$IsWindows;clientMatches=$false;sourceReady=$false;buildReady=$false;dataReady=$false;databasePrepared=$false;supervisorRunning=$false}
try{$s=Read-LocalSettings $Root;$v=Get-ClientExecutableVersion (Join-Path $s.clientRoot $p.client.relativeExe);$report.clientMatches=$v -eq $p.client.version;$report.actualClient=$v}catch{}
try{Assert-SourceReady "$Root/vendor/core" $p.core.commit (Get-ConsolePatch $Root $p);$report.sourceReady=$true}catch{}
try{Assert-BuildReady $Root $p;$report.buildReady=$true}catch{}
try{Assert-DataReady $Root $p;$report.dataReady=$true}catch{}
try{$db=Get-Content "$Root/runtime/database.json" -Raw | ConvertFrom-Json;$report.databasePrepared=$db.coreCommit -eq $p.core.commit -and $db.clientVersion -eq $p.client.version}catch{}
try{$report.supervisorRunning=[bool](Read-SupervisorState $Root)}catch{}
# Only this explicit allowlist is exported; no settings, accounts, database rows or raw logs.
$dest=Join-Path $Root 'diagnostic-summary.json'
Write-JsonFile $dest $report
Write-Host "Diagnostic summary: $dest"
Write-Host 'This reports preparation only. No gameplay result is inferred.'
