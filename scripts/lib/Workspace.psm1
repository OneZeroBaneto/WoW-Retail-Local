# SPDX-License-Identifier: GPL-2.0-or-later
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Read-Profile([string]$Root) {
    $p = Get-Content (Join-Path $Root 'sources.lock.json') -Raw | ConvertFrom-Json
    if ($p.schemaVersion -ne 1 -or $p.core.commit -notmatch '^[a-f0-9]{40}$' -or $p.database.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid source lock.' }
    if ($p.database.prefix -notmatch '^[a-z][a-z0-9_]{0,23}$' -or $p.realmName -notmatch '^[a-zA-Z0-9 -]{1,32}$') { throw 'Invalid database or realm name.' }
    return $p
}
function Assert-ConfigPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[;"\r\n\x00]') { throw 'Paths must not contain quotes, semicolons or line breaks.' }
}
function Write-JsonFile([string]$Path, $Value) {
    $tmp = "$Path.$([guid]::NewGuid()).tmp"
    [IO.File]::WriteAllText($tmp, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($tmp, $Path, $true)
}
function Protect-LocalDirectory([string]$Path) {
    if ($IsWindows) {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        Invoke-Native 'icacls.exe' @($Path,'/inheritance:r','/grant:r',"*$($sid):(OI)(CI)F",'*S-1-5-18:(OI)(CI)F') -Capture | Out-Null
    } else { [IO.File]::SetUnixFileMode($Path, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute) }
}
function Read-LocalSettings([string]$Root) {
    $s = Get-Content (Join-Path $Root 'local/settings.json') -Raw | ConvertFrom-Json
    if ($s.root -ne [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Project moved. Create a fresh local/settings.json via Configure; keep the old database/backup intact.' }
    foreach ($value in @($s.root,$s.mysqlRoot,$s.clientRoot,$s.boostRoot,$s.opensslRoot,$s.cmake,$s.sevenZip)) { Assert-ConfigPath $value }
    foreach ($key in @('rootPassword','databasePassword')) { if ($s.$key -notmatch '^[a-f0-9]{64}$') { throw "Invalid local secret: $key" } }
    return $s
}
function Set-ConfigValues([string]$Text, [System.Collections.IDictionary]$Values) {
    foreach ($key in $Values.Keys) {
        $pattern = '(?m)^\s*' + [regex]::Escape($key) + '\s*=.*$'
        $line = "$key = $($Values[$key])"
        if ([regex]::IsMatch($Text,$pattern)) { $Text = [regex]::Replace($Text,$pattern,[Text.RegularExpressions.MatchEvaluator]{ param($m) $line }) }
        else { $Text += "`n$line`n" }
    }
    return $Text
}
function Initialize-Workspace([string]$Root) {
    $Root = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
    Assert-ConfigPath $Root
    $p = Read-Profile $Root
    foreach ($dir in @('local','runtime','runtime/logs','runtime/data','runtime/certs','runtime/control','downloads','backups')) {
        New-Item -ItemType Directory (Join-Path $Root $dir) -Force | Out-Null
    }
    foreach ($dir in @('local','runtime','backups')) { Protect-LocalDirectory (Join-Path $Root $dir) }
    $path = Join-Path $Root 'local/settings.json'
    if (!(Test-Path $path)) {
        $s = [ordered]@{
            root=$Root; mysqlRoot='C:/Program Files/MySQL/MySQL Server 8.0'; clientRoot='C:/Games/World of Warcraft'
            boostRoot='C:/local/boost_1_86_0'; opensslRoot='C:/Program Files/OpenSSL-Win64'; cmake='cmake.exe'; sevenZip='C:/Program Files/7-Zip/7z.exe'
            rootPassword=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
            databasePassword=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
        }
        Write-JsonFile $path $s
    }
    $s = Read-LocalSettings $Root
    $base = $Root.Replace('\','/')
    $mysql = $s.mysqlRoot.Replace('\','/')
    $prefix = $p.database.prefix
    $connection = "127.0.0.1;$($p.database.port);$prefix;$($s.databasePassword);"
    $world = [ordered]@{
        RealmID=$p.database.realmId; BindIP='"127.0.0.1"'; WorldServerPort=$p.ports.world
        DataDir="`"$base/runtime/data`""; LogsDir="`"$base/runtime/logs`""; SourceDirectory="`"$base/vendor/core`""
        MySQLExecutable="`"$mysql/bin/mysql.exe`""; LoginDatabaseInfo="`"$connection$($prefix)_auth`""
        WorldDatabaseInfo="`"$connection$($prefix)_world`""; CharacterDatabaseInfo="`"$connection$($prefix)_characters`""
        HotfixDatabaseInfo="`"$connection$($prefix)_hotfixes`""; 'Updates.EnableDatabases'=0; 'Updates.AutoSetup'=0
        'Ra.Enable'=0; 'SOAP.Enabled'=0; 'Console.Enable'=1; 'mmap.enablePathFinding'=1
    }
    $bnet = [ordered]@{
        BindIP='"127.0.0.1"'; BattlenetPort=$p.ports.bnet; 'LoginREST.Port'=$p.ports.rest
        'LoginREST.ExternalAddress'='127.0.0.1'; 'LoginREST.LocalAddress'='127.0.0.1'
        LoginDatabaseInfo="`"$connection$($prefix)_auth`""; LogsDir="`"$base/runtime/logs`""; 'Updates.EnableDatabases'=0
        CertificatesFile="`"$base/runtime/certs/server.crt`""; PrivateKeyFile="`"$base/runtime/certs/server.key`""
    }
    if ($p.edition -eq 'forever') {
        $world.Expansion=0; $world.'Network.SkipBuildAuthKeyCheck'=1; $world.'Network.EnterEncryptedModeRegionGroup'=8
        $bnet.'Realm.CfgContentSetID'=137; $bnet.'Realm.SuperDistrictID'=2
        $world.'Realm.CfgContentSetID'=137; $world.'Realm.SuperDistrictID'=2
        $world.'Logger.sql.sql'='5,DBErrors'
        $bnet.'LoginREST.ExternalAddress'='trinity.actual.battle.net'; $bnet.'LoginREST.LocalAddress'='trinity.actual.battle.net'
    }
    foreach ($pair in @(@('worldserver',$world),@('bnetserver',$bnet))) {
        $text = Get-Content (Join-Path $Root "config/upstream/$($pair[0]).conf.dist") -Raw
        [IO.File]::WriteAllText((Join-Path $Root "runtime/$($pair[0]).conf"), (Set-ConfigValues $text $pair[1]), [Text.UTF8Encoding]::new($false))
    }
    $myIni = @"
[mysqld]
basedir="$mysql"
datadir="$base/runtime/mysql-data"
bind-address=127.0.0.1
port=$($p.database.port)
mysqlx=0
local-infile=0
max_allowed_packet=1G
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
log-error="$base/runtime/logs/mysql-error.log"
"@
    [IO.File]::WriteAllText((Join-Path $Root 'runtime/my.ini'),$myIni)
    foreach ($account in @('root','server')) {
        $username = if ($account -eq 'root') { 'root' } else { $prefix }
        $password = if ($account -eq 'root') { $s.rootPassword } else { $s.databasePassword }
        [IO.File]::WriteAllText((Join-Path $Root "local/$account.cnf"), "[client]`nhost=127.0.0.1`nport=$($p.database.port)`nprotocol=TCP`nuser=$username`npassword=$password`n")
    }
    return $s
}
function Assert-ClientVersion($Profile,[string]$Version) {
    if ($Version.Trim() -ne $Profile.client.version) { throw "Client $Version is not the pinned $($Profile.client.version)." }
}
function ConvertTo-ClientVersion([string]$FileVersion,[string]$ProductVersion) {
    # Numeric VS_FIXEDFILEINFO components are only 16 bits; current WoW build IDs exceed 65535.
    foreach($text in @($FileVersion,$ProductVersion)) {
        if($text -match '^\s*(\d+)[.,]\s*(\d+)[.,]\s*(\d+)(?:[.,]\s*|\s*\(\s*)(\d+)\)?(?:\s.*)?$') {
            return "$([int]$Matches[1]).$([int]$Matches[2]).$([int]$Matches[3]).$([int]$Matches[4])"
        }
    }
    throw 'Cannot read an unambiguous complete WoW build from executable version strings.'
}
function Assert-FileHash([string]$Path,[string]$Sha256) {
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Sha256) { throw "SHA-256 mismatch: $Path" }
}
function Get-RealmSql($Profile) {
    $p=$Profile; $db=$p.database.prefix + '_auth'
    return @"
USE $db;
INSERT INTO realmlist (id,name,address,localAddress,localSubnetMask,port,icon,flag,timezone,allowedSecurityLevel,population,gamebuild,Region,Battlegroup)
VALUES ($($p.database.realmId),'$($p.realmName)','127.0.0.1','127.0.0.1','255.255.255.0',$($p.ports.world),0,0,1,0,0,$($p.client.build),1,1)
ON DUPLICATE KEY UPDATE name=VALUES(name),address=VALUES(address),localAddress=VALUES(localAddress),port=VALUES(port),gamebuild=VALUES(gamebuild),flag=0;
DELETE FROM realmlist WHERE id <> $($p.database.realmId);
"@
}
function Invoke-Native {
    param([string]$File, [string[]]$Arguments=@(), [switch]$Capture, [string]$InputText, [string]$WorkingDirectory, [System.Collections.IDictionary]$Environment=@{})
    $info=[Diagnostics.ProcessStartInfo]::new($File)
    $info.UseShellExecute=$false
    foreach ($a in $Arguments) { $info.ArgumentList.Add($a) }
    foreach ($key in $Environment.Keys) { $info.Environment[$key]=[string]$Environment[$key] }
    if ($WorkingDirectory) { $info.WorkingDirectory=$WorkingDirectory }
    $info.RedirectStandardInput=$PSBoundParameters.ContainsKey('InputText')
    $info.RedirectStandardOutput=[bool]$Capture; $info.RedirectStandardError=[bool]$Capture
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$info
    try {
        if (!$process.Start()) { throw "Could not start $File" }
        if ($Capture) { $outTask=$process.StandardOutput.ReadToEndAsync(); $errTask=$process.StandardError.ReadToEndAsync() }
        if ($info.RedirectStandardInput) { $process.StandardInput.Write($InputText); $process.StandardInput.Close() }
        $process.WaitForExit()
        if ($Capture) { $output=$outTask.GetAwaiter().GetResult(); $errors=$errTask.GetAwaiter().GetResult() }
        if ($process.ExitCode -ne 0) { throw "$([IO.Path]::GetFileName($File)) failed (exit $($process.ExitCode)). $(if ($Capture) { $errors })" }
        if ($Capture) { return $output.TrimEnd("`r","`n") }
    } finally { $process.Dispose() }
}
function Assert-DataReady([string]$Root,$Profile) {
    $data=Join-Path $Root 'runtime/data'
    $marker=Get-Content (Join-Path $data 'extraction.json') -Raw | ConvertFrom-Json
    if ($marker.coreCommit -ne $Profile.core.commit -or $marker.clientVersion -ne $Profile.client.version) { throw 'Extracted data does not match source/client lock.' }
    foreach ($dir in @('dbc','gt','maps','vmaps','mmaps')) {
        if (!(Test-Path (Join-Path $data $dir)) -or !(Get-ChildItem (Join-Path $data $dir) -File -Recurse | Select-Object -First 1)) { throw "Missing extracted $dir data." }
    }
}
function Get-ConsolePatch([string]$Root,$Profile) {
    $patch=Join-Path $Root 'patches/0001-windows-pipe-console.patch'
    Assert-FileHash $patch $Profile.core.patchSha256
    return $patch
}
function Assert-SourceReady([string]$Source,[string]$Commit,[string]$PatchFile) {
    $actual = Invoke-Native 'git' @('-C',$Source,'rev-parse','HEAD') -Capture
    if ($actual -ne $Commit) { throw 'Core source differs from the pinned commit. No checkout/reset was performed.' }
    if ($PatchFile) {
        $untracked=Invoke-Native 'git' @('-C',$Source,'ls-files','--others','--exclude-standard') -Capture
        $diff=Invoke-Native 'git' @('-C',$Source,'diff','--no-ext-diff','--no-textconv','--no-color','--no-renames','--full-index','--no-indent-heuristic','-U3','--src-prefix=a/','--dst-prefix=b/','HEAD','--') -Capture
        $expected=(Get-Content $PatchFile -Raw).Replace("`r`n","`n").TrimEnd("`r","`n")
        if ($untracked -or $diff.Replace("`r`n","`n") -cne $expected) { throw 'Core must contain exactly the recorded console patch and no other changes.' }
    } else {
        $dirty = Invoke-Native 'git' @('-C',$Source,'status','--porcelain') -Capture
        if ($dirty) { throw 'Core contains local changes. Preserve them before preparing a new version.' }
    }
}
function Get-LocalMySQLConnection([string]$Root,$Profile,[switch]$Passwordless) {
    $options=if($Passwordless){@('--no-defaults')}else{@("--defaults-file=$(Join-Path $Root 'local/root.cnf')")}
    $options+=@('--host=127.0.0.1',"--port=$($Profile.database.port)",'--protocol=TCP','--user=root')
    if($Passwordless){$options+='--skip-password'}
    # MySQL 8.0 reads .mylogin.cnf even with --defaults-file/--no-defaults.
    # A unique nonexistent path prevents inherited user login-path overrides.
    $absent=Join-Path $Root ('local/no-login-'+[guid]::NewGuid()+'.cnf')
    if(Test-Path $absent){throw 'Unexpected MySQL login-file collision.'}
    return @{Arguments=$options;Environment=@{MYSQL_TEST_LOGIN_FILE=$absent}}
}
function Assert-CertificateDirectoryEmpty([string]$Directory) {
    if (@(Get-ChildItem $Directory -File).Count) { throw 'Certificates already exist. Refusing to replace keys or trust.' }
}
function Install-RuntimeLibraries($Settings,[string]$Runtime) {
    $candidates=[ordered]@{
        'libmysql.dll'=@((Join-Path $Settings.mysqlRoot 'lib/libmysql.dll'),(Join-Path $Settings.mysqlRoot 'bin/libmysql.dll'))
        'libcrypto-3-x64.dll'=@((Join-Path $Settings.opensslRoot 'bin/libcrypto-3-x64.dll'))
        'libssl-3-x64.dll'=@((Join-Path $Settings.opensslRoot 'bin/libssl-3-x64.dll'))
        'legacy.dll'=@((Join-Path $Settings.opensslRoot 'bin/legacy.dll'),(Join-Path $Settings.opensslRoot 'lib/ossl-modules/legacy.dll'))
    }
    $selected=@{}
    foreach($name in $candidates.Keys) {
        $found=@($candidates[$name] | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        if(!$found.Count){throw "Missing runtime library $name. Install the full matching x64 dependency, then retry Build."}
        $selected[$name]=$found[0]
    }
    # MySQL may depend on OpenSSL 1.1 while the core uses OpenSSL 3.
    # Preserve both families; selected OpenSSL libraries take precedence for identical names.
    foreach($file in @(Get-ChildItem (Join-Path $Settings.mysqlRoot 'bin') -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^lib(crypto|ssl).*\.dll$' })) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $Runtime $file.Name) -Force
    }
    foreach($name in $selected.Keys){Copy-Item -LiteralPath $selected[$name] -Destination (Join-Path $Runtime $name) -Force}
}
function Read-CascProduct([string]$ClientRoot,[string]$Version) {
    $lines = @(Get-Content (Join-Path $ClientRoot '.build.info') | Where-Object { $_.Trim() })
    $headers = @($lines[0].Split('|') | ForEach-Object { ($_ -split '!')[0] })
    $productMatches = @()
    foreach ($row in ($lines | Select-Object -Skip 1)) {
        $values=$row.Split('|'); $data=@{}
        for ($i=0; $i -lt $headers.Count; $i++) { if($i -lt $values.Count){$data[$headers[$i]]=$values[$i]} }
        if ($data.Version -eq $Version -and $data.Active -eq '1' -and $data.Product -match '^[a-z0-9_]+$') { $productMatches += $data.Product }
    }
    $productMatches=@($productMatches | Select-Object -Unique)
    if ($productMatches.Count -ne 1) { throw 'No unambiguous active CASC product for the pinned client build.' }
    return $productMatches[0]
}
function Copy-OfflineSnapshot([string]$Root) {
    # Caller must hold instance.lock and have confirmed all variant ports are free.
    $stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString().Substring(0,8)
    $stage=Join-Path $Root "backups/incomplete-$stamp"
    $dest=Join-Path $Root "backups/$stamp"
    New-Item -ItemType Directory (Join-Path $stage 'runtime') -Force | Out-Null
    Protect-LocalDirectory $stage
    foreach($path in @('runtime/mysql-data','runtime/certs','runtime/database.json','runtime/worldserver.conf','runtime/bnetserver.conf','runtime/my.ini','local','sources.lock.json')) {
        $source=Join-Path $Root $path
        if(!(Test-Path $source)){throw "Missing backup source: $path. Incomplete copy retained at $stage"}
        Copy-Item -LiteralPath $source -Destination (Join-Path $stage (Split-Path $path -Parent)) -Recurse -Force
    }
    Write-JsonFile (Join-Path $stage 'snapshot.json') @{complete=$true;createdAt=[DateTime]::UtcNow.ToString('o');sourceRoot=$Root;method='offline-copy';note='Contains passwords and certificate private keys; keep private.'}
    Move-Item $stage $dest
    return $dest
}
Export-ModuleMember -Function *
