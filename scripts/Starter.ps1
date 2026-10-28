#Requires -Version 7.4
param([switch]$Restore,[string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName))
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Windows.psm1" -DisableNameChecking
Assert-Windows
Import-Module NetTCPIP
$p=Read-Profile $Root;$s=Read-LocalSettings $Root
if($p.edition -ne 'retail'){throw 'The first-play profile is specific to Retail.'}
$world=$p.database.prefix+'_world';$backup="$Root/local/northshire-original.json"
Invoke-OfflineDatabase $Root $p $s {
    $rows=[int](Invoke-LocalQuery $Root $s "SELECT COUNT(*) FROM $world.playercreateinfo WHERE race=1 AND class=1 AND map=0;")
    if($rows -ne 1){throw 'Expected exactly one normal human warrior start on map 0.'}
    $current=Invoke-LocalQuery $Root $s "SELECT COALESCE(CAST(npe_map AS CHAR),'NULL') FROM $world.playercreateinfo WHERE race=1 AND class=1;"
    if($Restore) {
        $old=Get-Content $backup -Raw | ConvertFrom-Json
        if($old.coreCommit -ne $p.core.commit -or $old.npeMap -notmatch '^(NULL|[0-9]+)$' -or $current -ne 'NULL'){throw 'Starter data changed; refusing to replace it.'}
        Invoke-LocalSQL $Root $s "UPDATE $world.playercreateinfo SET npe_map=$($old.npeMap) WHERE race=1 AND class=1 AND npe_map IS NULL;"
        Remove-Item $backup
        Write-Host 'Original human warrior NPE map restored for future characters.'
    }else{
        if(!(Test-Path $backup)) {
            if($current -notmatch '^(NULL|[0-9]+)$'){throw 'Unexpected starter map value.'}
            Write-JsonFile $backup @{coreCommit=$p.core.commit;npeMap=$current}
        }else{
            $old=Get-Content $backup -Raw | ConvertFrom-Json
            if($old.coreCommit -ne $p.core.commit -or ($current -ne 'NULL' -and $current -ne $old.npeMap)){throw 'Starter data changed after previous setup.'}
        }
        Invoke-LocalSQL $Root $s "UPDATE $world.playercreateinfo SET npe_map=NULL WHERE race=1 AND class=1;"
        $after=Invoke-LocalQuery $Root $s "SELECT COUNT(*) FROM $world.playercreateinfo WHERE race=1 AND class=1 AND map=0 AND npe_map IS NULL;"
        if($after -ne '1'){throw 'First-play start profile did not persist.'}
        Write-Host 'New human warriors start in Northshire, including when the client requests NPE. Original choice is backed up; restore with scripts/Starter.ps1 -Restore.'
    }
}
