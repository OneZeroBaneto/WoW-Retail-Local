#Requires -Version 7.4
param([Parameter(Mandatory)][string]$BoostRoot)
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
$root=[IO.Directory]::GetParent([IO.Directory]::GetParent($PSScriptRoot).FullName).FullName
Import-Module "$root/scripts/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$root/scripts/lib/Process.psm1" -DisableNameChecking
Import-Module "$root/scripts/lib/Windows.psm1" -DisableNameChecking
Assert-Windows
Import-Module NetTCPIP
if($env:GITHUB_ACTIONS -ne 'true'){throw 'This script provisions only a disposable GitHub Actions Windows runner.'}
$p=Read-Profile $root
$opensslRoot='C:/libs/wow-openssl-3.5.9'
$installer=Join-Path $env:RUNNER_TEMP 'wow-openssl.exe'
Invoke-WebRequest 'https://slproweb.com/download/Win64OpenSSL-3_5_9.exe' -OutFile $installer
Assert-FileHash $installer '5fe338c81d62515df7292f16542a0eef2a29db3efc023cd5a8c08ec3c97027ae'
Invoke-Native $installer @('/VERYSILENT','/SP-','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$opensslRoot")
$s=Initialize-Workspace $root
$s.boostRoot=$BoostRoot
$s.opensslRoot=$opensslRoot
$s.mysqlRoot='C:/Program Files/MySQL/MySQL Server 8.0'
Write-JsonFile "$root/local/settings.json" $s
$s=Initialize-Workspace $root
& "$root/tests/Run.Tests.ps1"
& "$root/tests/Readiness.Tests.ps1"
& "$root/tests/Parse-All.ps1"
Prepare-CoreSource $root $p
Build-Core $root $p $s -WithTests
Download-Database $root $p $s
Initialize-Database $root $p $s
New-ServerCertificates $root $p $s
$mysql=$null;$bnet=$null
try {
    Assert-PortsFree @($p.database.port,$p.ports.bnet,$p.ports.rest)
    $mysql=Start-OwnedProcess (Get-MySQLTool $s 'mysqld') @("--defaults-file=$root/runtime/my.ini",'--no-monitor') "$root/runtime" "$root/runtime/logs/ci-mysql"
    Wait-OwnedPort $mysql $p.database.port
    $bnet=Start-OwnedProcess "$root/runtime/bnetserver.exe" @('-c',"$root/runtime/bnetserver.conf") "$root/runtime" "$root/runtime/logs/ci-bnet"
    Wait-OwnedPort $bnet $p.ports.bnet
    Wait-OwnedPort $bnet $p.ports.rest
    $form=Invoke-RestMethod "https://127.0.0.1:$($p.ports.rest)/bnetserver/login/" -SkipCertificateCheck -TimeoutSec 15
    if($form.srp_url -ne "https://127.0.0.1:$($p.ports.rest)/bnetserver/login/srp/"){throw 'BNet returned an unexpected login endpoint.'}
} finally {
    if($bnet){if(!$bnet.Process.HasExited){$bnet.Process.Kill()};$null=Complete-OwnedProcess $bnet 30}
    if($mysql){if(!$mysql.Process.HasExited){Stop-LocalMySQL $root $s};$null=Complete-OwnedProcess $mysql 120}
}
$package=Join-Path $root 'dist/windows-server'
New-Item -ItemType Directory "$package/runtime" -Force | Out-Null
# Explicit allowlist: never upload local settings, generated configs, DBs, logs or certificates.
foreach($name in @('worldserver','bnetserver','mapextractor','vmap4extractor','vmap4assembler','mmaps_generator')) {
    Copy-Item "$root/runtime/$name.exe" "$package/runtime/"
}
Get-ChildItem "$root/runtime" -File -Filter '*.dll' | Copy-Item -Destination "$package/runtime/"
Copy-Item "$root/runtime/build.json" "$package/runtime/"
Copy-Item "$root/sources.lock.json" $package
$files=@(Get-ChildItem "$package/runtime" -File | ForEach-Object {@{name=$_.Name;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
Write-JsonFile "$package/verification.json" @{
    coreCommit=$p.core.commit;patchSha256=$p.core.patchSha256;clientVersion=$p.client.version
    runner=$env:RUNNER_OS;runId=$env:GITHUB_RUN_ID;coreTests=$true;databaseImport=$true;bnetRest=$true
    gameClientTested=$false;gameplayTested=$false;files=$files
}
Write-Host 'Windows build, core tests, DB import and BNet REST passed. Real client login and gameplay are still separate acceptance tests.'
