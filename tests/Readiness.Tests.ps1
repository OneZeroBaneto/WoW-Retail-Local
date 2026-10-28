#Requires -Version 7.4
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module "$root/scripts/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$root/scripts/lib/Readiness.psm1" -DisableNameChecking
$script:passed=0
function Check([string]$Name,[scriptblock]$Body){& $Body;$script:passed++;Write-Host "PASS $Name"}
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}
function MustThrow([scriptblock]$Body){$thrown=$false;try{& $Body | Out-Null}catch{$thrown=$true};Assert $thrown 'Expected refusal.'}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('wow-client-test-'+[guid]::NewGuid())
New-Item -ItemType Directory $temp | Out-Null
try {
    $good="auth_build`t1`nhuman_warrior_start`t1`nhostile_spawns`t74`nloot_entries`t3`nkill_quest`t1"
    Check 'Missing starter or loot content cannot be reported ready' {
        $ok=Test-ReadinessRows $good
        Assert $ok.ready 'Valid fixture was rejected.'
        Assert (!$ok.gameplayVerified) 'Data alone was marked as gameplay.'
        foreach($name in @('human_warrior_start','hostile_spawns','loot_entries','kill_quest','auth_build')) {
            $bad=[regex]::Replace($good,"(?m)^$name\t\d+","$name`t0")
            Assert (!(Test-ReadinessRows $bad).ready) "Missing $name was accepted."
        }
        Assert (!(Test-ReadinessRows "auth_build`t1").ready) 'Incomplete results accepted.'
        MustThrow { Test-ReadinessRows "$good`nauth_build`t1" }
    }
    Check 'Client portal preserves unrelated settings and restores exact original bytes' {
        $config=Join-Path $temp 'Config.wtf';$backup=Join-Path $temp 'portal-backup'
        $original=[Text.Encoding]::UTF8.GetBytes("SET portal `"EU`"`r`nSET locale `"deDE`"`r`nSET gxWindow `"1`"`r`n")
        [IO.File]::WriteAllBytes($config,$original)
        Set-LocalClientPortal $config $backup
        $text=Get-Content $config -Raw
        Assert ($text.Contains('SET portal "127.0.0.1"')) 'Local portal missing.'
        Assert ($text.Contains('SET locale "deDE"')) 'Locale changed.'
        Set-LocalClientPortal $config $backup
        Restore-ClientPortal $config $backup
        Assert ([Convert]::ToHexString([IO.File]::ReadAllBytes($config)) -eq [Convert]::ToHexString($original)) 'Original bytes were not restored.'
    }
    Check 'New client settings are removed on restore, later user edits are preserved' {
        $config=Join-Path $temp 'new/Config.wtf';$backup=Join-Path $temp 'new-backup'
        Set-LocalClientPortal $config $backup
        Restore-ClientPortal $config $backup
        Assert (!(Test-Path $config)) 'New file not removed by restore.'
        Set-LocalClientPortal $config $backup
        Add-Content $config 'SET locale "frFR"'
        MustThrow { Restore-ClientPortal $config $backup }
        Assert ((Get-Content $config -Raw).Contains('frFR')) 'Later user edit lost.'
    }
    Check 'Client portal refuses a duplicate conflicting portal and unsupported configuration encoding' {
        $config=Join-Path $temp 'duplicate.wtf'
        [IO.File]::WriteAllText($config,"SET portal `"EU`"`nSET portal `"US`"`n")
        MustThrow { Set-LocalClientPortal $config (Join-Path $temp 'duplicate-backup') }
        [IO.File]::WriteAllBytes($config,[byte[]]@(255,254,83,0,69,0))
        MustThrow { Set-LocalClientPortal $config (Join-Path $temp 'encoding-backup') }
    }
    Check 'Existing accounts require matching saved credentials; retry never replaces their password' {
        MustThrow { Resolve-PlayerAccountPlan 'player@local' $true $null }
        $saved=[pscustomobject]@{email='player@local';password='abcdef012345abcdef012345';status='pending'}
        $retry=Resolve-PlayerAccountPlan 'player@local' $true $saved
        Assert ($retry.action -eq 'verify') 'Existing account would be recreated.'
        Assert ($retry.credentials.password -eq $saved.password) 'Existing password changed.'
        MustThrow { Resolve-PlayerAccountPlan 'other@local' $true $saved }
        MustThrow { Resolve-PlayerAccountPlan "a'@local" $false $null }
        $fresh=Resolve-PlayerAccountPlan 'player@local' $false $null
        Assert ($fresh.action -eq 'create') 'Fresh account not queued for creation.'
        Assert ($fresh.credentials.password -match '^[a-f0-9]{24}$') 'Generated password cannot safely pass the core console parser.'
    }
}finally{Remove-Item $temp -Recurse -Force}
Write-Host "$script:passed readiness tests passed."
