#Requires -Version 7.4
param([Parameter(Mandatory)][string]$Root)
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Workspace.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'lib/Process.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'lib/Windows.psm1') -DisableNameChecking
Assert-Windows
Import-Module NetTCPIP
$p=Read-Profile $Root; $s=Read-LocalSettings $Root
$lock=$null; $mysql=$null; $world=$null; $bnet=$null
$statePath=Join-Path $Root 'runtime/control/supervisor.json'
$ownsState=$false
try {
    $lock=[IO.File]::Open((Join-Path $Root 'runtime/instance.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    Assert-PortsFree @($p.database.port,$p.ports.bnet,$p.ports.rest,$p.ports.world)
    Assert-BuildReady $Root $p
    Assert-DataReady $Root $p
    $db=Get-Content (Join-Path $Root 'runtime/database.json') -Raw | ConvertFrom-Json
    if($db.coreCommit -ne $p.core.commit -or $db.clientVersion -ne $p.client.version){throw 'Database preparation does not match this source/client lock.'}
    foreach($file in @('runtime/certs/server.crt','runtime/certs/server.key')){Require-File (Join-Path $Root $file)}
    if($p.edition -eq 'forever') {
        $addresses=@([Net.Dns]::GetHostAddresses('trinity.actual.battle.net'))
        if(!$addresses.Count -or @($addresses | Where-Object { ![Net.IPAddress]::IsLoopback($_) }).Count){throw 'Complete the loopback hosts entry in docs/WINDOWS-SETUP.md first.'}
    }
    $session=[guid]::NewGuid().ToString()
    $state=@{pid=$PID;started=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks.ToString();session=$session;ready=$false;root=$Root}
    Write-JsonFile $statePath $state; $ownsState=$true
    $stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+$session.Substring(0,8)
    $runtime=Join-Path $Root 'runtime'
    $mysql=Start-OwnedProcess (Get-MySQLTool $s 'mysqld') @("--defaults-file=$runtime/my.ini",'--no-monitor') $runtime "$runtime/logs/$stamp-mysql"
    Wait-OwnedPort $mysql $p.database.port
    Invoke-LocalSQL $Root $s 'SELECT 1;'
    $world=Start-OwnedProcess "$runtime/worldserver.exe" @('-c',"$runtime/worldserver.conf") $runtime "$runtime/logs/$stamp-world"
    Wait-OwnedPort $world $p.ports.world 300
    $bnet=Start-OwnedProcess "$runtime/bnetserver.exe" @('-c',"$runtime/bnetserver.conf") $runtime "$runtime/logs/$stamp-bnet"
    Wait-OwnedPort $bnet $p.ports.bnet
    Wait-OwnedPort $bnet $p.ports.rest
    $state.ready=$true; Write-JsonFile $statePath $state
    Write-Host "$($p.realmName): services listening on loopback. This is not gameplay acceptance."
    Write-Host 'Leave this window open. Use Stop.bat for a clean shutdown; Console.bat sends world commands.'
    Write-Host "Logs: $runtime/logs"
    $stop=$false
    while(!$stop) {
        foreach($job in @($mysql,$world,$bnet)) { if($job.Process.HasExited){throw "A server process exited; see $($job.LogPrefix)."} }
        foreach($request in @(Get-ChildItem "$runtime/control" -Filter '*.request.json' -File | Sort-Object Name)) {
            try { $r=Get-Content $request.FullName -Raw | ConvertFrom-Json } finally { Remove-Item -LiteralPath $request.FullName -Force }
            if($r.session -ne $session){continue}
            if($r.action -eq 'stop'){$stop=$true;break}
            if($r.action -eq 'command'){Send-OwnedInput $world ([string]$r.command)}
        }
        Start-Sleep -Milliseconds 250
    }
} finally {
    # The world must have finished saving before either authentication or MySQL is stopped.
    if($world) {
        if(!$world.Process.HasExited){Send-OwnedInput $world 'server shutdown 0'}
        $null=Complete-OwnedProcess $world 120
    }
    if($bnet) {
        if(!$bnet.Process.HasExited){$bnet.Process.Kill()}
        $null=Complete-OwnedProcess $bnet 30
    }
    if($mysql) {
        if(!$mysql.Process.HasExited){Stop-LocalMySQL $Root $s}
        $null=Complete-OwnedProcess $mysql 120
    }
    if($ownsState -and (Test-Path $statePath)){Remove-Item $statePath}
    if($lock){$lock.Dispose()}
}
