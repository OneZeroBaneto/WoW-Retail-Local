# SPDX-License-Identifier: GPL-2.0-or-later
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Workspace.psm1') -DisableNameChecking
function Get-ReadinessSql($Profile) {
    if($Profile.edition -ne 'retail'){throw 'The Northshire readiness checks are specific to Retail.'}
    $world=$Profile.database.prefix+'_world';$auth=$Profile.database.prefix+'_auth'
    return @"
SELECT 'auth_build',COUNT(*) FROM $auth.build_auth_key k JOIN $auth.build_info b ON b.build=k.build WHERE k.build=$($Profile.client.build) AND k.platform='Win' AND k.arch='x64' AND k.type='WoW' AND LENGTH(k.key)>0;
SELECT 'human_warrior_start',COUNT(*) FROM $world.playercreateinfo WHERE race=1 AND class=1 AND map=0 AND ABS(position_x+8914.57)<10 AND ABS(position_y+133.909)<10;
SELECT 'hostile_spawns',COUNT(*) FROM $world.creature c JOIN $world.creature_template t ON t.entry=c.id JOIN $world.playercreateinfo p ON p.race=1 AND p.class=1 AND p.map=c.map WHERE c.id IN(49871,49874) AND c.PhaseId=0 AND c.PhaseGroup=0 AND c.phaseUseFlags=0 AND FIND_IN_SET('0',c.spawnDifficulties)>0 AND (POW(c.position_x-p.position_x,2)+POW(c.position_y-p.position_y,2)+POW(c.position_z-p.position_z,2))<=62500;
SELECT 'loot_entries',COUNT(*) FROM $world.creature_template_difficulty d JOIN $world.creature_loot_template l ON l.Entry=d.LootID WHERE d.Entry IN(49871,49874) AND d.DifficultyID=0 AND l.QuestRequired=0 AND l.Chance>0;
SELECT 'kill_quest',COUNT(*) FROM $world.quest_template q JOIN $world.creature_queststarter s ON s.quest=q.ID JOIN $world.quest_objectives o ON o.QuestID=q.ID WHERE q.ID=28766 AND s.id=197 AND o.ObjectID=49871 AND o.Amount=6;
"@
}
function Test-ReadinessRows([string]$Rows) {
    $values=@{}
    foreach($line in $Rows -split "\r?\n") {
        if(!$line.Trim()){continue}
        if($line -notmatch '^([a-z_]+)\t([0-9]+)$'){throw 'Unexpected readiness query response.'}
        $key=$Matches[1];$value=[long]$Matches[2]
        if($values.ContainsKey($key)){throw "Duplicate readiness metric: $key"}
        $values[$key]=$value
    }
    $checks=@(foreach($name in @('auth_build','human_warrior_start','hostile_spawns','loot_entries','kill_quest')) {
        [pscustomobject]@{name=$name;value=$values[$name];passed=($values.ContainsKey($name) -and $values[$name] -gt 0)}
    })
    return [pscustomobject]@{ready=(@($checks | Where-Object {!$_.passed}).Count -eq 0);gameplayVerified=$false;checks=$checks}
}
function Resolve-PlayerAccountPlan([string]$Email,[bool]$Exists,$SavedCredentials) {
    if($Email -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{0,50}@[A-Za-z0-9.-]{1,60}$'){throw 'Use a simple account email such as player@local.'}
    if($SavedCredentials) {
        if($SavedCredentials.email -ine $Email -or $SavedCredentials.password -notmatch '^[a-f0-9]{24}$'){throw 'Saved account does not match this setup. It was not changed.'}
        $credentials=$SavedCredentials
    } else {
        if($Exists){throw 'Account already exists without matching saved credentials. Its password will not be changed.'}
        $credentials=[pscustomobject]@{email=$Email;password=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(12)).ToLowerInvariant();status='pending'}
    }
    return [pscustomobject]@{action=$(if($Exists){'verify'}else{'create'});credentials=$credentials}
}
function Invoke-PreparationStages($Profile,[string]$ClientVersion,[object[]]$Stages) {
    Assert-ClientVersion $Profile $ClientVersion
    foreach($stage in $Stages) {
        $ready=$false
        try{$ready=[bool](& $stage.ready)}catch{$ready=$false}
        if($ready){Write-Host "READY: $($stage.name)";continue}
        Write-Host "PREPARE: $($stage.name)"
        & $stage.run
        if(!(& $stage.ready)){throw "Preparation stage $($stage.name) did not satisfy its completion checks."}
    }
}
function Get-BytesHash([byte[]]$Bytes) {return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()}
function Write-AtomicBytes([string]$Path,[byte[]]$Bytes) {
    $tmp="$Path.$([guid]::NewGuid()).tmp"
    [IO.File]::WriteAllBytes($tmp,$Bytes);[IO.File]::Move($tmp,$Path,$true)
}
function Read-ClientText([byte[]]$Bytes) {
    try{$text=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes)}catch{throw 'Client settings must be valid UTF-8; original file was not changed.'}
    $bom=$text.StartsWith([string][char]0xFEFF,[StringComparison]::Ordinal)
    if($bom){$text=$text.Substring(1)}
    return [pscustomobject]@{text=$text;bom=$bom}
}
function Assert-LocalPortal([string]$Text) {
    $matches=[regex]::Matches($Text,'(?im)^[\t ]*SET[\t ]+portal\b[^\r\n]*')
    if($matches.Count -ne 1 -or $matches[0].Value -notmatch '^[\t ]*SET[\t ]+portal[\t ]+"127\.0\.0\.1"[\t ]*$'){throw 'Client portal changed after setup. Refusing to overwrite a different server setting.'}
}
function Set-LocalClientPortal([string]$ConfigPath,[string]$BackupDirectory) {
    $ConfigPath=[IO.Path]::GetFullPath($ConfigPath)
    $marker=Join-Path $BackupDirectory 'portal.json'
    if(Test-Path $marker) {
        $saved=Get-Content $marker -Raw | ConvertFrom-Json
        if($saved.configPath -ne $ConfigPath -or !(Test-Path $ConfigPath)){throw 'Client config path changed since portal setup.'}
        Assert-LocalPortal (Read-ClientText ([IO.File]::ReadAllBytes($ConfigPath))).text
        return
    }
    if((Test-Path $BackupDirectory) -and @(Get-ChildItem $BackupDirectory -Force).Count){throw 'Unrecognized portal backup already exists.'}
    $existed=Test-Path $ConfigPath
    [byte[]]$bytes=@()
    if($existed){$bytes=[IO.File]::ReadAllBytes($ConfigPath)}
    $encoding=[Text.UTF8Encoding]::new($false,$true)
    $decoded=Read-ClientText $bytes;$text=$decoded.text;$bom=$decoded.bom
    $pattern='(?im)^[\t ]*SET[\t ]+portal\b[^\r\n]*'
    $found=[regex]::Matches($text,$pattern)
    if($found.Count -gt 1){throw 'Multiple portal settings found. Original file was not changed.'}
    $line='SET portal "127.0.0.1"'
    if($found.Count){$text=[regex]::Replace($text,$pattern,$line)}
    else{$newline=if($text.Contains("`r`n")){"`r`n"}else{"`n"};if($text -and !$text.EndsWith("`n")){$text+=$newline};$text+=$line+$newline}
    if($bom){$text=([string][char]0xFEFF)+$text}
    $localBytes=$encoding.GetBytes($text)
    New-Item -ItemType Directory $BackupDirectory -Force | Out-Null
    Protect-LocalDirectory $BackupDirectory
    if($existed){[IO.File]::WriteAllBytes((Join-Path $BackupDirectory 'original.wtf'),$bytes)}
    Write-JsonFile $marker @{configPath=$ConfigPath;existed=$existed;originalHash=(Get-BytesHash $bytes);localHash=(Get-BytesHash $localBytes)}
    New-Item -ItemType Directory (Split-Path $ConfigPath -Parent) -Force | Out-Null
    Write-AtomicBytes $ConfigPath $localBytes
}
function Restore-ClientPortal([string]$ConfigPath,[string]$BackupDirectory) {
    $ConfigPath=[IO.Path]::GetFullPath($ConfigPath)
    $marker=Join-Path $BackupDirectory 'portal.json';$saved=Get-Content $marker -Raw | ConvertFrom-Json
    if($saved.configPath -ne $ConfigPath -or !(Test-Path $ConfigPath)){throw 'Client config path changed after setup.'}
    $currentBytes=[IO.File]::ReadAllBytes($ConfigPath)
    $original=Join-Path $BackupDirectory 'original.wtf'
    [byte[]]$bytes=@()
    if($saved.existed) {
        $bytes=[IO.File]::ReadAllBytes($original)
        if((Get-BytesHash $bytes) -ne $saved.originalHash){throw 'Original client backup hash mismatch.'}
    }
    if((Get-BytesHash $currentBytes) -eq $saved.localHash) {
        if($saved.existed){Write-AtomicBytes $ConfigPath $bytes}else{Remove-Item $ConfigPath}
    }else{
        # WoW saves unrelated settings on exit. Restore only the portal in that case.
        $current=Read-ClientText $currentBytes
        Assert-LocalPortal $current.text
        $pattern='(?im)^[\t ]*SET[\t ]+portal\b[^\r\n]*'
        $oldPortal=[regex]::Match((Read-ClientText $bytes).text,$pattern)
        if($oldPortal.Success){$restored=[regex]::Replace($current.text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $oldPortal.Value})}
        else{$restored=[regex]::Replace($current.text,$pattern+'(?:\r?\n)?','')}
        if($current.bom){$restored=([string][char]0xFEFF)+$restored}
        Write-AtomicBytes $ConfigPath ([Text.UTF8Encoding]::new($false).GetBytes($restored))
    }
    if($saved.existed){Remove-Item $original}
    Remove-Item $marker
    if(!@(Get-ChildItem $BackupDirectory -Force).Count){Remove-Item $BackupDirectory}
}
Export-ModuleMember -Function *
