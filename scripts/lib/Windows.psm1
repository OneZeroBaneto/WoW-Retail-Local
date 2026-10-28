# SPDX-License-Identifier: GPL-2.0-or-later
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Workspace.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'Process.psm1') -DisableNameChecking
function Assert-Windows {
    if (!$IsWindows -or ![Environment]::Is64BitProcess) { throw 'Deployment requires Windows x64 and PowerShell 7.4+. Portable tests can run on macOS.' }
}
function Require-File([string]$File) {
    if (!(Test-Path -LiteralPath $File -PathType Leaf)) { throw "Missing file: $File" }
}
function Get-MySQLTool($Settings,[string]$Name) { return Join-Path $Settings.mysqlRoot "bin/$Name.exe" }
function Get-ClientExecutableVersion([string]$Path) {
    Require-File $Path
    $version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    return ConvertTo-ClientVersion $version.FileVersion $version.ProductVersion
}
function Prepare-CoreSource([string]$Root,$Profile) {
    $source=Join-Path $Root 'vendor/core'
    $patch=Get-ConsolePatch $Root $Profile
    if (Test-Path $source) { Assert-SourceReady $source $Profile.core.commit $patch; return }
    $stage=Join-Path $Root ('vendor/core-fetch-'+[guid]::NewGuid())
    New-Item -ItemType Directory $stage -Force | Out-Null
    Invoke-Native 'git' @('init',$stage)
    Invoke-Native 'git' @('-C',$stage,'config','core.autocrlf','false')
    Invoke-Native 'git' @('-C',$stage,'remote','add','origin',$Profile.core.repository)
    Invoke-Native 'git' @('-C',$stage,'fetch','--depth','1','origin',$Profile.core.commit)
    Invoke-Native 'git' @('-C',$stage,'checkout','--detach','FETCH_HEAD')
    Invoke-Native 'git' @('-C',$stage,'submodule','update','--init','--recursive')
    Assert-SourceReady $stage $Profile.core.commit
    Invoke-Native 'git' @('-C',$stage,'apply','--check',$patch)
    Invoke-Native 'git' @('-C',$stage,'apply',$patch)
    Assert-SourceReady $stage $Profile.core.commit $patch
    Move-Item $stage $source
}
function Build-Core([string]$Root,$Profile,$Settings,[switch]$WithTests) {
    $source=Join-Path $Root 'vendor/core'
    Assert-SourceReady $source $Profile.core.commit (Get-ConsolePatch $Root $Profile)
    $buildMarker=Join-Path $Root 'runtime/build.json'
    if(Test-Path $buildMarker){Remove-Item $buildMarker}
    Require-File (Get-MySQLTool $Settings 'mysql')
    $configure=@('-S',$source,'-B',(Join-Path $Root 'build'),'-G','Visual Studio 17 2022','-A','x64',
        '-DTOOLS=1','-DSCRIPTS=static',"-DBUILD_TESTING=$(if($WithTests){'ON'}else{'OFF'})",'-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
        "-DCMAKE_INSTALL_PREFIX=$(Join-Path $Root 'runtime')","-DBOOST_ROOT=$($Settings.boostRoot)",
        "-DOPENSSL_ROOT_DIR=$($Settings.opensslRoot)","-DMYSQL_INCLUDE_DIR=$(Join-Path $Settings.mysqlRoot 'include')",
        "-DMYSQL_LIBRARY=$(Join-Path $Settings.mysqlRoot 'lib/libmysql.lib')","-DMYSQL_EXECUTABLE=$(Get-MySQLTool $Settings 'mysql')")
    Invoke-Native $Settings.cmake $configure
    Invoke-Native $Settings.cmake @('--build',(Join-Path $Root 'build'),'--config','Release','--parallel','2')
    if($WithTests) {
        $testPrograms=@(Get-ChildItem (Join-Path $Root 'build') -Recurse -File -Filter 'tests.exe' | Where-Object { $_.DirectoryName -match '[\\/]Release$' })
        if($testPrograms.Count -ne 1){throw 'Expected one compiled core test executable.'}
        Install-RuntimeLibraries $Settings $testPrograms[0].DirectoryName
        Invoke-Native 'ctest' @('--test-dir',(Join-Path $Root 'build'),'-C','Release','--output-on-failure','--no-tests=error')
    }
    Invoke-Native $Settings.cmake @('--install',(Join-Path $Root 'build'),'--config','Release')
    foreach ($exe in @('worldserver','bnetserver','mapextractor','vmap4extractor','vmap4assembler','mmaps_generator')) { Require-File (Join-Path $Root "runtime/$exe.exe") }
    Install-RuntimeLibraries $Settings (Join-Path $Root 'runtime')
    foreach($exe in @('worldserver','bnetserver')) {
        Invoke-Native (Join-Path $Root "runtime/$exe.exe") @('--version') -WorkingDirectory (Join-Path $Root 'runtime')
    }
    # Validate OpenSSL's legacy provider from the executable directory as used by the core.
    Invoke-Native (Join-Path $Settings.opensslRoot 'bin/openssl.exe') @('list','-providers','-provider-path',(Join-Path $Root 'runtime'),'-provider','legacy') -Capture | Out-Null
    Write-JsonFile $buildMarker @{ coreCommit=$Profile.core.commit; consolePatchSha256=$Profile.core.patchSha256; builtAt=[DateTime]::UtcNow.ToString('o'); platform='windows-x64' }
}
function Download-Database([string]$Root,$Profile,$Settings) {
    $archive=Join-Path $Root 'downloads/tdb.7z'
    if (!(Test-Path $archive)) {
        $partial="$archive.partial"
        Invoke-WebRequest -Uri $Profile.database.url -OutFile $partial
        Assert-FileHash $partial $Profile.database.sha256
        Move-Item $partial $archive
    }
    Assert-FileHash $archive $Profile.database.sha256
    Require-File $Settings.sevenZip
    $stage=Join-Path $Root ('downloads/tdb-'+[guid]::NewGuid())
    Invoke-Native $Settings.sevenZip @('x','-y',"-o$stage",$archive)
    foreach ($name in $Profile.database.files) {
        $candidates=@(Get-ChildItem $stage -Recurse -File | Where-Object Name -eq $name)
        if ($candidates.Count -ne 1) { throw "Expected exactly one $name in database release." }
        Copy-Item -LiteralPath $candidates[0].FullName -Destination (Join-Path $Root "runtime/$name")
    }
}
function Assert-BuildReady([string]$Root,$Profile) {
    $build=Get-Content (Join-Path $Root 'runtime/build.json') -Raw | ConvertFrom-Json
    $null=Get-ConsolePatch $Root $Profile
    if ($build.coreCommit -ne $Profile.core.commit -or $build.platform -ne 'windows-x64' -or $build.consolePatchSha256 -ne $Profile.core.patchSha256) { throw 'Windows build does not match source/patch lock.' }
    foreach ($exe in @('worldserver','bnetserver')) { Require-File (Join-Path $Root "runtime/$exe.exe") }
}
function Extract-ClientData([string]$Root,$Profile,$Settings) {
    Assert-BuildReady $Root $Profile
    $exe=Join-Path $Settings.clientRoot $Profile.client.relativeExe
    Require-File $exe
    Assert-ClientVersion $Profile (Get-ClientExecutableVersion $exe)
    $product=Read-CascProduct $Settings.clientRoot $Profile.client.version
    $stage=Join-Path $Root ('runtime/extract-'+[guid]::NewGuid())
    New-Item -ItemType Directory $stage | Out-Null
    Invoke-Native (Join-Path $Root 'runtime/mapextractor.exe') @('-i',$Settings.clientRoot,'-o',$stage,'-p',$product) -WorkingDirectory $stage
    Invoke-Native (Join-Path $Root 'runtime/vmap4extractor.exe') @('-d',$Settings.clientRoot,'-p',$product) -WorkingDirectory $stage
    New-Item -ItemType Directory (Join-Path $stage 'vmaps') -Force | Out-Null
    Invoke-Native (Join-Path $Root 'runtime/vmap4assembler.exe') @((Join-Path $stage 'Buildings'),(Join-Path $stage 'vmaps')) -WorkingDirectory $stage
    New-Item -ItemType Directory (Join-Path $stage 'mmaps') -Force | Out-Null
    Invoke-Native (Join-Path $Root 'runtime/mmaps_generator.exe') @() -WorkingDirectory $stage
    foreach ($folder in @('dbc','gt','maps','vmaps','mmaps')) {
        if (!(Get-ChildItem (Join-Path $stage $folder) -File -Recurse | Select-Object -First 1)) { throw "Extractor did not create $folder." }
    }
    Write-JsonFile (Join-Path $stage 'extraction.json') @{coreCommit=$Profile.core.commit;clientVersion=$Profile.client.version;product=$product;extractedAt=[DateTime]::UtcNow.ToString('o')}
    $destination=Join-Path $Root 'runtime/data'
    if (Test-Path $destination) { Move-Item $destination (Join-Path $Root ('runtime/data-previous-'+[guid]::NewGuid())) }
    Move-Item $stage $destination
    Assert-DataReady $Root $Profile
}
function Invoke-LocalSQL([string]$Root,$Settings,[string]$Sql) {
    $connection=Get-LocalMySQLConnection $Root (Read-Profile $Root)
    Invoke-Native (Get-MySQLTool $Settings 'mysql') ($connection.Arguments+@('--batch')) -Environment $connection.Environment -InputText $Sql -Capture | Out-Null
}
function Invoke-LocalQuery([string]$Root,$Settings,[string]$Sql) {
    $connection=Get-LocalMySQLConnection $Root (Read-Profile $Root)
    return Invoke-Native (Get-MySQLTool $Settings 'mysql') ($connection.Arguments+@('--batch','--skip-column-names','--raw')) -Environment $connection.Environment -InputText $Sql -Capture
}
function Invoke-OfflineDatabase([string]$Root,$Profile,$Settings,[scriptblock]$Operation) {
    $guard=[IO.File]::Open((Join-Path $Root 'runtime/instance.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $job=$null
    try {
        Assert-PortsFree @($Profile.database.port,$Profile.ports.bnet,$Profile.ports.rest,$Profile.ports.world)
        Require-File (Join-Path $Root 'runtime/database.json')
        $job=Start-OwnedProcess (Get-MySQLTool $Settings 'mysqld') @("--defaults-file=$Root/runtime/my.ini",'--no-monitor') "$Root/runtime" (Join-Path $Root ('runtime/logs/offline-mysql-'+[guid]::NewGuid()))
        Wait-OwnedPort $job $Profile.database.port
        & $Operation
    } finally {
        if($job){if(!$job.Process.HasExited){Stop-LocalMySQL $Root $Settings};$null=Complete-OwnedProcess $job 120}
        $guard.Dispose()
    }
}
function Stop-LocalMySQL([string]$Root,$Settings,[switch]$Passwordless) {
    $connection=Get-LocalMySQLConnection $Root (Read-Profile $Root) -Passwordless:$Passwordless
    Invoke-Native (Get-MySQLTool $Settings 'mysqladmin') ($connection.Arguments+@('shutdown')) -Environment $connection.Environment -Capture | Out-Null
}
function Initialize-Database([string]$Root,$Profile,$Settings) {
    Assert-BuildReady $Root $Profile
    Assert-SourceReady (Join-Path $Root 'vendor/core') $Profile.core.commit (Get-ConsolePatch $Root $Profile)
    foreach($name in $Profile.database.files){Require-File (Join-Path $Root "runtime/$name")}
    Assert-PortsFree @($Profile.database.port)
    $data=Join-Path $Root 'runtime/mysql-data'
    $marker=Join-Path $Root 'local/database-bootstrap.json'
    if (!(Test-Path $marker)) {
        if (Test-Path $data) { throw 'Existing MySQL data without ownership marker. Refusing to initialize or replace it.' }
        Write-JsonFile $marker @{initialized=$false;passwordSet=$false}
    }
    $state=Get-Content $marker -Raw | ConvertFrom-Json
    if (!$state.initialized) {
        if (Test-Path $data) { throw 'Incomplete MySQL initialization; preserve and inspect runtime/mysql-data before retrying.' }
        Invoke-Native (Get-MySQLTool $Settings 'mysqld') @("--defaults-file=$(Join-Path $Root 'runtime/my.ini')",'--initialize-insecure')
        $state.initialized=$true; Write-JsonFile $marker $state
    }
    $job=Start-OwnedProcess (Get-MySQLTool $Settings 'mysqld') @("--defaults-file=$(Join-Path $Root 'runtime/my.ini')",'--no-monitor') (Join-Path $Root 'runtime') (Join-Path $Root ('runtime/logs/setup-mysql-'+[guid]::NewGuid()))
    try {
        Wait-OwnedPort $job $Profile.database.port
        if (!$state.passwordSet) {
            $alreadySet=$false
            try { Invoke-LocalSQL $Root $Settings 'SELECT 1;'; $alreadySet=$true } catch { }
            if (!$alreadySet) {
                $connection=Get-LocalMySQLConnection $Root $Profile -Passwordless
                Invoke-Native (Get-MySQLTool $Settings 'mysql') $connection.Arguments -Environment $connection.Environment -InputText "ALTER USER 'root'@'localhost' IDENTIFIED BY '$($Settings.rootPassword)';" -Capture | Out-Null
            }
            $state.passwordSet=$true; Write-JsonFile $marker $state
        }
        $prefix=$Profile.database.prefix
        $sql="CREATE USER IF NOT EXISTS '$prefix'@'127.0.0.1' IDENTIFIED BY '$($Settings.databasePassword)';`n"
        foreach($db in @('auth','characters','world','hotfixes')) {
            $name="$($prefix)_$db"
            $sql+="CREATE DATABASE IF NOT EXISTS $name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`nGRANT ALL PRIVILEGES ON $name.* TO '$prefix'@'127.0.0.1';`n"
        }
        Invoke-LocalSQL $Root $Settings $sql
        $config=Get-Content (Join-Path $Root 'runtime/worldserver.conf') -Raw
        $update=Set-ConfigValues $config @{'Updates.EnableDatabases'=15;'Updates.AutoSetup'=1}
        $updatePath=Join-Path $Root 'runtime/update-worldserver.conf'
        [IO.File]::WriteAllText($updatePath,$update)
        $connection=Get-LocalMySQLConnection $Root $Profile
        Invoke-Native (Join-Path $Root 'runtime/worldserver.exe') @('-c',$updatePath,'-u') -WorkingDirectory (Join-Path $Root 'runtime') -Environment $connection.Environment
        Invoke-LocalSQL $Root $Settings (Get-RealmSql $Profile)
        Write-JsonFile (Join-Path $Root 'runtime/database.json') @{coreCommit=$Profile.core.commit;clientVersion=$Profile.client.version;initializedAt=[DateTime]::UtcNow.ToString('o')}
    } finally {
        if (!$job.Process.HasExited) {
            Stop-LocalMySQL $Root $Settings -Passwordless:(!$state.passwordSet)
        }
        $null=Complete-OwnedProcess $job 120
    }
}
function New-ServerCertificates([string]$Root,$Profile,$Settings) {
    $openssl=Join-Path $Settings.opensslRoot 'bin/openssl.exe'; Require-File $openssl
    $dir=Join-Path $Root 'runtime/certs'
    Assert-CertificateDirectoryEmpty $dir
    $dns=if($Profile.edition -eq 'forever'){'trinity.actual.battle.net'}else{'localhost'}
    $constraints=if($Profile.edition -eq 'forever'){'nameConstraints=critical,permitted;DNS:actual.battle.net'}else{'nameConstraints=critical,permitted;DNS:localhost,permitted;IP:127.0.0.1/255.255.255.255'}
    Invoke-Native $openssl @('req','-x509','-newkey','rsa:2048','-noenc','-days','3650','-keyout',"$dir/ca.key",'-out',"$dir/ca.crt",'-subj',"/CN=$($Profile.realmName) Local CA",'-addext','basicConstraints=critical,CA:TRUE','-addext','keyUsage=critical,keyCertSign,cRLSign','-addext',$constraints)
    Invoke-Native $openssl @('req','-new','-newkey','rsa:2048','-noenc','-keyout',"$dir/server.key",'-out',"$dir/server.csr",'-subj',"/CN=$dns")
    [IO.File]::WriteAllText("$dir/server.ext","basicConstraints=critical,CA:FALSE`nkeyUsage=critical,digitalSignature,keyEncipherment`nextendedKeyUsage=serverAuth`nsubjectAltName=DNS:$dns,IP:127.0.0.1`n")
    Invoke-Native $openssl @('x509','-req','-in',"$dir/server.csr",'-CA',"$dir/ca.crt",'-CAkey',"$dir/ca.key",'-CAcreateserial','-out',"$dir/server.crt",'-days','825','-sha256','-extfile',"$dir/server.ext")
    Add-Content "$dir/server.crt" (Get-Content "$dir/ca.crt" -Raw)
    Write-Host "Certificates created. Client setup/trust is described in docs/WINDOWS-SETUP.md."
}
Export-ModuleMember -Function *
