#Requires -Version 7.4
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$module = Join-Path $repo 'scripts/lib/Workspace.psm1'
if (!(Test-Path $module)) { throw 'Workspace behavior is not implemented yet.' }
Import-Module $module -Force -DisableNameChecking
$script:passed = 0
function Check([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Host "PASS $Name"
}
function Assert($Condition, [string]$Message) { if (!$Condition) { throw $Message } }
function MustThrow([scriptblock]$Body) {
    $thrown = $false
    try { & $Body | Out-Null } catch { $thrown = $true }
    Assert $thrown 'Expected rejection did not happen.'
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('wow prep test ' + [guid]::NewGuid())
try {
    New-Item -ItemType Directory $temp | Out-Null
    Copy-Item (Join-Path $repo 'sources.lock.json') $temp
    Copy-Item (Join-Path $repo 'config') $temp -Recurse
    Copy-Item (Join-Path $repo 'patches') $temp -Recurse
    $profile = Read-Profile $temp
    Check 'Repeated configuration keeps credentials and database identity' {
        $first = Initialize-Workspace $temp
        $again = Initialize-Workspace $temp
        Assert ($first.databasePassword -eq $again.databasePassword) 'Credentials changed.'
        Assert ($first.rootPassword -eq $again.rootPassword) 'Root credentials changed.'
        Assert ($again.databasePassword -match '^[a-f0-9]{64}$') 'Database secret malformed.'
        $world = Get-Content (Join-Path $temp 'runtime/worldserver.conf') -Raw
        Assert ($world -match 'BindIP = "127.0.0.1"') 'Public binding.'
        Assert ($world.Contains($profile.database.prefix + '_characters')) 'Wrong database.'
        Assert ($world -match 'Updates.EnableDatabases\s*=\s*0') 'Normal start may unexpectedly migrate.'
        Assert ($world.Contains($temp.Replace('\','/'))) 'Space-containing root was not preserved.'
    }
    Check 'Invalid config paths are rejected before any runtime is created' {
        foreach ($bad in @('bad;path', 'bad"path', "bad`npath")) { MustThrow { Assert-ConfigPath $bad } }
        Assert-ConfigPath "C:/Games/Player's WoW"
    }
    Check 'Moving a configured project cannot silently reuse another runtime' {
        $moved = "$temp-moved"
        New-Item -ItemType Directory $moved | Out-Null
        Copy-Item (Join-Path $temp 'local') $moved -Recurse
        MustThrow { Read-LocalSettings $moved }
        Remove-Item $moved -Recurse -Force
    }
    Check 'Client build mismatch is rejected' {
        Assert-ClientVersion $profile $profile.client.version
        MustThrow { Assert-ClientVersion $profile '1.60.1.1' }
    }
    Check 'Downloaded bytes must match SHA-256' {
        $file = Join-Path $temp 'download.bin'
        [IO.File]::WriteAllText($file, 'abc')
        Assert-FileHash $file 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
        MustThrow { Assert-FileHash $file ('0' * 64) }
    }
    Check 'Realm SQL is loopback-only and targets the configured realm/build' {
        $sql = Get-RealmSql $profile
        Assert ($sql.Contains("VALUES ($($profile.database.realmId),")) 'Wrong realm.'
        Assert ($sql.Contains(",$($profile.client.build),")) 'Wrong game build.'
        Assert ($sql -match '127\.0\.0\.1') 'Wrong address.'
        Assert ($sql -notmatch 'DROP DATABASE|TRUNCATE') 'Destructive SQL.'
    }
    Check 'Native arguments with spaces and shell syntax stay literal' {
        $fixture = Join-Path $temp 'echo args.ps1'
        Set-Content $fixture '[Console]::Write($args[0])'
        $literal = 'a b; $(touch nope) "quoted"'
        $actual = Invoke-Native (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })) @('-NoProfile','-File',$fixture,$literal) -Capture
        Assert ($actual -ceq $literal) 'Argument was changed or interpreted.'
    }
    Check 'Native failures propagate as failures' {
        MustThrow { Invoke-Native (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })) @('-NoProfile','-Command','exit 17') -Capture }
        $message=''
        try{Invoke-Native (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })) @('-NoProfile','-Command','[Console]::WriteLine("failure-on-stdout"); exit 17') -Capture}catch{$message=$_.Exception.Message}
        Assert ($message.Contains('failure-on-stdout')) 'Native stdout diagnostic was lost.'
    }
    Check 'Extraction marker must match pinned build and core' {
        MustThrow { Assert-DataReady $temp $profile }
        $data = Join-Path $temp 'runtime/data'
        foreach ($name in @('dbc','gt','maps','vmaps','mmaps')) {
            New-Item -ItemType Directory (Join-Path $data $name) -Force | Out-Null
            Set-Content (Join-Path $data "$name/fixture.dat") 'fixture'
        }
        @{ coreCommit=$profile.core.commit; clientVersion=$profile.client.version } | ConvertTo-Json | Set-Content (Join-Path $data 'extraction.json')
        Assert-DataReady $temp $profile
        @{ coreCommit=('0'*40); clientVersion=$profile.client.version } | ConvertTo-Json | Set-Content (Join-Path $data 'extraction.json')
        MustThrow { Assert-DataReady $temp $profile }
    }
    Check 'Owned process captures output and accepts a graceful console command' {
        $pm = Join-Path $repo 'scripts/lib/Process.psm1'
        Assert (Test-Path $pm) 'Process lifecycle is not implemented yet.'
        Import-Module $pm -Force -DisableNameChecking
        $worker = Join-Path $temp 'worker.ps1'
        Set-Content $worker '[Console]::WriteLine("READY"); $line=[Console]::ReadLine(); [Console]::WriteLine("COMMAND="+$line); if($line -ne "server shutdown 0"){exit 19}'
        $job = Start-OwnedProcess (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })) @('-NoProfile','-File',$worker) $temp (Join-Path $temp 'worker')
        Send-OwnedInput $job 'server shutdown 0'
        $exit = Complete-OwnedProcess $job 10
        Assert ($exit -eq 0) ('Graceful shutdown failed: ' + $exit + ' ' + (Get-Content (Join-Path $temp 'worker.out.log') -Raw) + (Get-Content (Join-Path $temp 'worker.err.log') -Raw))
        $output = Get-Content (Join-Path $temp 'worker.out.log') -Raw
        Assert ($output.Contains('COMMAND=server shutdown 0')) 'Command did not reach the child.'
    }
    Check 'Occupied ports are refused without terminating their owner' {
        $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
        $listener.Start()
        try {
            MustThrow { Assert-PortsFree @($listener.LocalEndpoint.Port) }
            Assert ($listener.Server.IsBound) 'Listener was disturbed.'
        } finally { $listener.Stop() }
    }
    Check 'Source validation refuses modified or wrong upstream checkout' {
        $source = Join-Path $temp 'vendor/core'
        New-Item -ItemType Directory $source -Force | Out-Null
        Invoke-Native 'git' @('init',$source) -Capture | Out-Null
        Invoke-Native 'git' @('-C',$source,'-c','user.email=test@example.invalid','-c','user.name=Test','commit','--allow-empty','-m','fixture') -Capture | Out-Null
        $sha = Invoke-Native 'git' @('-C',$source,'rev-parse','HEAD') -Capture
        Assert-SourceReady $source $sha
        MustThrow { Assert-SourceReady $source ('0'*40) }
        Set-Content (Join-Path $source 'local-change.txt') 'keep this'
        MustThrow { Assert-SourceReady $source $sha }
    }
    Check 'CASC product comes from the matching active build instead of a guessed folder name' {
        $client = Join-Path $temp 'client'
        New-Item -ItemType Directory $client | Out-Null
        Set-Content (Join-Path $client '.build.info') "Active!DEC:1|Version!STRING:0|Product!STRING:0`n1|$($profile.client.version)|wow_test_product`n1|1.2.3.4|wow"
        Assert ((Read-CascProduct $client $profile.client.version) -eq 'wow_test_product') 'Wrong CASC product.'
        MustThrow { Read-CascProduct $client '0.0.0.0' }
    }
    Check 'Offline snapshot includes database/config/secrets and excludes game data' {
        New-Item -ItemType Directory (Join-Path $temp 'runtime/mysql-data') -Force | Out-Null
        Set-Content (Join-Path $temp 'runtime/mysql-data/fixture.ibd') 'persistent character data'
        Set-Content (Join-Path $temp 'runtime/database.json') '{}'
        $snapshot=Copy-OfflineSnapshot $temp
        Assert ((Get-Content (Join-Path $snapshot 'runtime/mysql-data/fixture.ibd') -Raw).Trim() -eq 'persistent character data') 'Database copy missing.'
        Assert (Test-Path (Join-Path $snapshot 'local/settings.json')) 'Recovery credentials missing.'
        Assert (Test-Path (Join-Path $snapshot 'snapshot.json')) 'Completion marker missing.'
        Assert (!(Test-Path (Join-Path $snapshot 'runtime/data'))) 'Reproducible maps unnecessarily copied.'
    }
    Check 'Source accepts exactly the recorded console patch, rejects extra tracked and untracked changes' {
        $source=Join-Path $temp 'patched-core'
        $relative='src/server/worldserver/CommandLine/CliRunnable.cpp'
        New-Item -ItemType Directory (Split-Path (Join-Path $source $relative)) -Force | Out-Null
        Copy-Item (Join-Path $repo 'tests/native/upstream/CliRunnable.cpp') (Join-Path $source $relative)
        Invoke-Native 'git' @('init',$source) -Capture | Out-Null
        Invoke-Native 'git' @('-C',$source,'config','core.autocrlf','false')
        Invoke-Native 'git' @('-C',$source,'add','.')
        Invoke-Native 'git' @('-C',$source,'-c','user.email=test@example.invalid','-c','user.name=Test','commit','-m','fixture') -Capture | Out-Null
        $sha=Invoke-Native 'git' @('-C',$source,'rev-parse','HEAD') -Capture
        $patch=Get-ConsolePatch $temp $profile
        MustThrow { Assert-SourceReady $source $sha $patch }
        Invoke-Native 'git' @('-C',$source,'apply',$patch)
        Assert-SourceReady $source $sha $patch
        Set-Content (Join-Path $source 'extra.txt') 'untracked'
        MustThrow { Assert-SourceReady $source $sha $patch }
        Remove-Item (Join-Path $source 'extra.txt')
        Add-Content (Join-Path $source $relative) '// another change'
        MustThrow { Assert-SourceReady $source $sha $patch }
    }
    Check 'MySQL child receives fixed connection and isolated login environment, parent stays unchanged' {
        $before=$env:MYSQL_TEST_LOGIN_FILE
        try {
            $env:MYSQL_TEST_LOGIN_FILE='existing-user-login.cnf'
            $fixture=Join-Path $temp 'mysql-args.ps1'
            Set-Content $fixture '[Console]::WriteLine($env:MYSQL_TEST_LOGIN_FILE); foreach($value in $args){[Console]::WriteLine($value)}'
            foreach($passwordless in @($false,$true)) {
                $connection=Get-LocalMySQLConnection $temp $profile -Passwordless:$passwordless
                $actual=Invoke-Native (Join-Path $PSHOME $(if($IsWindows){'pwsh.exe'}else{'pwsh'})) (@('-NoProfile','-File',$fixture)+$connection.Arguments) -Environment $connection.Environment -Capture
                Assert ($actual.Contains($connection.Environment.MYSQL_TEST_LOGIN_FILE)) 'Login file override did not reach child.'
                Assert (!(Test-Path $connection.Environment.MYSQL_TEST_LOGIN_FILE)) 'Login override points at existing credentials.'
                $lines=$actual -split '\r?\n'
                foreach($required in @('--host=127.0.0.1',"--port=$($profile.database.port)",'--protocol=TCP','--user=root')) {Assert ($lines -contains $required) "Not a separate native argument: $required"}
                $expectedFirst=if($passwordless){'--no-defaults'}else{"--defaults-file=$(Join-Path $temp 'local/root.cnf')"}
                Assert ($lines[1] -eq $expectedFirst) 'First MySQL option was concatenated with later options.'
                Assert (!$actual.Contains('existing-user-login.cnf')) 'User login leaked into child.'
                Assert ($env:MYSQL_TEST_LOGIN_FILE -eq 'existing-user-login.cnf') 'Parent environment was changed.'
                if($passwordless){Assert ($lines -contains '--skip-password') 'Bootstrap can inherit a password.'}
            }
        } finally { $env:MYSQL_TEST_LOGIN_FILE=$before }
    }
    Check 'Source preparation fetches a fixed revision, applies the patch, resumes and preserves later changes' {
        Import-Module (Join-Path $repo 'scripts/lib/Windows.psm1') -DisableNameChecking
        $remote=Join-Path $temp 'patched-core'
        $sha=Invoke-Native 'git' @('-C',$remote,'rev-parse','HEAD') -Capture
        $workspace=Join-Path $temp 'fresh source workspace'
        New-Item -ItemType Directory $workspace | Out-Null
        Copy-Item (Join-Path $repo 'patches') $workspace -Recurse
        $fixtureProfile=[pscustomobject]@{core=[pscustomobject]@{repository=$remote;commit=$sha;patchSha256=$profile.core.patchSha256}}
        Prepare-CoreSource $workspace $fixtureProfile
        Prepare-CoreSource $workspace $fixtureProfile
        $checkout=Join-Path $workspace 'vendor/core'
        Assert-SourceReady $checkout $sha (Get-ConsolePatch $workspace $fixtureProfile)
        Set-Content (Join-Path $checkout 'my-work.txt') 'preserve this'
        MustThrow { Prepare-CoreSource $workspace $fixtureProfile }
        Assert ((Get-Content (Join-Path $checkout 'my-work.txt') -Raw).Trim() -eq 'preserve this') 'User source change was lost.'
    }
    Check 'Empty certificate directory works under StrictMode and existing keys are preserved' {
        Assert-CertificateDirectoryEmpty (Join-Path $temp 'runtime/certs')
        $key=Join-Path $temp 'runtime/certs/server.key'; Set-Content $key 'keep-key'
        MustThrow { Assert-CertificateDirectoryEmpty (Join-Path $temp 'runtime/certs') }
        Assert ((Get-Content $key -Raw).Trim() -eq 'keep-key') 'Existing key changed.'
    }
    Check 'Runtime libraries include the legacy provider and fail before copying incomplete dependencies' {
        $deps=Join-Path $temp 'deps';$target=Join-Path $temp 'dll-runtime'
        foreach($dir in @("$deps/mysql/lib","$deps/mysql/bin","$deps/openssl/bin","$deps/openssl/lib/ossl-modules",$target)){New-Item -ItemType Directory $dir -Force | Out-Null}
        $settings=@{mysqlRoot="$deps/mysql";opensslRoot="$deps/openssl"}
        foreach($file in @('mysql/lib/libmysql.dll','openssl/bin/libcrypto-3-x64.dll','openssl/bin/libssl-3-x64.dll')){Set-Content "$deps/$file" $file}
        MustThrow { Install-RuntimeLibraries $settings $target }
        Assert (@(Get-ChildItem $target).Count -eq 0) 'Partial dependency set was installed.'
        Set-Content "$deps/openssl/lib/ossl-modules/legacy.dll" 'legacy-provider'
        Set-Content "$deps/mysql/bin/libcrypto-1_1-x64.dll" 'mysql-crypto-dependency'
        Set-Content "$deps/mysql/bin/libssl-1_1-x64.dll" 'mysql-ssl-dependency'
        Set-Content "$deps/mysql/bin/libcrypto-3-x64.dll" 'old-mysql-copy'
        Install-RuntimeLibraries $settings $target
        Assert (Test-Path "$target/libcrypto-1_1-x64.dll") 'MySQL transitive crypto DLL was omitted.'
        Assert (Test-Path "$target/libssl-1_1-x64.dll") 'MySQL transitive SSL DLL was omitted.'
        Assert ((Get-Content "$target/libcrypto-3-x64.dll" -Raw).Trim() -eq 'openssl/bin/libcrypto-3-x64.dll') 'Old MySQL copy replaced selected OpenSSL library.'
        Assert ((Get-Content "$target/legacy.dll" -Raw).Trim() -eq 'legacy-provider') 'Wrong legacy provider copied.'
    }
} finally { if (Test-Path $temp) { Remove-Item $temp -Recurse -Force } }
Write-Host "$script:passed tests passed."
