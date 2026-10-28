#Requires -Version 7.4
param([Parameter(Mandatory)][string]$MySQLRoot)
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module "$repo/scripts/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$repo/scripts/lib/Windows.psm1" -DisableNameChecking
Import-Module "$repo/scripts/lib/Process.psm1" -DisableNameChecking
Assert-Windows
if($env:GITHUB_ACTIONS -ne 'true'){throw 'This integration test is restricted to disposable CI runners.'}
Import-Module NetTCPIP
$root=Join-Path $env:RUNNER_TEMP ('wow mysql test '+[guid]::NewGuid())
New-Item -ItemType Directory $root | Out-Null
Copy-Item "$repo/config" $root -Recurse
$p=Read-Profile $repo;$p.database.port=34313
Write-JsonFile "$root/sources.lock.json" $p
$s=Initialize-Workspace $root;$s.mysqlRoot=$MySQLRoot
Write-JsonFile "$root/local/settings.json" $s
$s=Initialize-Workspace $root
Assert-PortsFree @($p.database.port)
$job=$null;$passwordSet=$false
try {
    Invoke-Native (Get-MySQLTool $s 'mysqld') @("--defaults-file=$root/runtime/my.ini",'--initialize-insecure')
    $job=Start-OwnedProcess (Get-MySQLTool $s 'mysqld') @("--defaults-file=$root/runtime/my.ini",'--no-monitor') "$root/runtime" "$root/runtime/logs/native-mysql"
    Wait-OwnedPort $job $p.database.port
    $c=Get-LocalMySQLConnection $root $p -Passwordless
    Invoke-Native (Get-MySQLTool $s 'mysql') $c.Arguments -Environment $c.Environment -InputText "ALTER USER 'root'@'localhost' IDENTIFIED BY '$($s.rootPassword)';" -Capture | Out-Null
    $passwordSet=$true
    $port=Invoke-LocalQuery $root $s 'SELECT @@port;'
    if($port -ne '34313'){throw 'MySQL client reached the wrong instance.'}
    Invoke-LocalSQL $root $s 'CREATE DATABASE native_smoke; CREATE TABLE native_smoke.example (id INT PRIMARY KEY); INSERT INTO native_smoke.example VALUES (1);'
    if((Invoke-LocalQuery $root $s 'SELECT COUNT(*) FROM native_smoke.example;') -ne '1'){throw 'Native MySQL persistence check failed.'}
    Write-Host 'PASS real Windows MySQL: initialize, set root password, isolated query, SQL write/read.'
}finally{
    if($job){if(!$job.Process.HasExited){Stop-LocalMySQL $root $s -Passwordless:(!$passwordSet)};$code=Complete-OwnedProcess $job 120;if($code -ne 0){throw "MySQL shutdown exit $code"}}
}
Write-Host 'PASS native MySQL clean shutdown.'
