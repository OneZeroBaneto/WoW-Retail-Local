#Requires -Version 7.4
param([string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName))
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Windows.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Process.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Readiness.psm1" -DisableNameChecking
Assert-Windows
Import-Module NetTCPIP
$p=Read-Profile $Root;$s=Read-LocalSettings $Root
$operation={Test-ReadinessRows (Invoke-LocalQuery $Root $s (Get-ReadinessSql $p))}
$state=Read-SupervisorState $Root
if($state){if(!$state.ready){throw 'Server is still starting. Retry when ready.'};$result=& $operation}
else{$result=Invoke-OfflineDatabase $Root $p $s $operation}
Write-JsonFile "$Root/runtime/readiness.json" $result
foreach($check in $result.checks){Write-Host "$(if($check.passed){'PASS'}else{'OPEN'}) $($check.name): $($check.value)"}
if(!$result.ready){throw 'Required auth/starter/mob/loot/quest data is missing.'}
Write-Host 'Required data is present. Follow docs/FIRST-PLAY.md to verify the real game.'
