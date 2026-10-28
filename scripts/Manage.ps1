#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Configure','Check','Source','Build','DatabaseFiles','Extract','Database','Certificates','Start','Stop','Console','Backup')][string]$Action,
    [string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName),
    [string]$Command
)
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/Workspace.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'lib/Process.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'lib/Windows.psm1') -DisableNameChecking
$Root=[IO.Path]::GetFullPath($Root)
try {
    $p=Read-Profile $Root
    if($Action -eq 'Configure') {
        # Fresh configuration can be prepared on Mac, but it belongs to that root.
        # Windows users configure their own root after cloning/unzipping.
        if(Read-SupervisorState $Root){throw 'Stop the server before changing configuration.'}
        $lockDir=Join-Path $Root 'runtime'; New-Item -ItemType Directory $lockDir -Force | Out-Null
        $guard=[IO.File]::Open((Join-Path $lockDir 'instance.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try{$null=Initialize-Workspace $Root}finally{$guard.Dispose()}
        Write-Host "Prepared local/settings.json. Set Windows paths there and rerun Configure. Secrets are not printed."
        exit 0
    }
    if($Action -eq 'Check') {
        Write-Host "Edition: $($p.edition); target client: $($p.client.version); source: $($p.core.commit)"
        $failures=[Collections.Generic.List[string]]::new()
        if(!$IsWindows){$failures.Add('Windows x64 is required for build/server/client execution.')}
        try{$s=Read-LocalSettings $Root}catch{$failures.Add('Run Configure and set local Windows paths.');$s=$null}
        if($s) {
            foreach($tool in @((Get-MySQLTool $s 'mysqld'),(Get-MySQLTool $s 'mysql'),(Get-MySQLTool $s 'mysqladmin'),$s.sevenZip,(Join-Path $s.opensslRoot 'bin/openssl.exe'))){if(!(Test-Path $tool)){$failures.Add("Missing: $tool")}}
            foreach($exe in @('git',$s.cmake)){if(!(Get-Command $exe -ErrorAction SilentlyContinue)){$failures.Add("Missing command: $exe")}}
            if($IsWindows) {
                $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
                if(!(Test-Path $vswhere)){$failures.Add('Install Visual Studio 2022 with Desktop C++ workload.')}
                else { $vs=Invoke-Native $vswhere @('-latest','-products','*','-version','[17.4,18.0)','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-property','installationPath') -Capture; if(!$vs){$failures.Add('Visual Studio 2022 C++ tools missing.')} }
                try{Require-File (Join-Path $s.boostRoot 'boost/version.hpp')}catch{$failures.Add($_.Exception.Message)}
                $client=Join-Path $s.clientRoot $p.client.relativeExe
                try {Require-File $client; Assert-ClientVersion $p ([Diagnostics.FileVersionInfo]::GetVersionInfo($client).FileVersion); $null=Read-CascProduct $s.clientRoot $p.client.version}catch{$failures.Add($_.Exception.Message)}
            }
        }
        foreach($check in @({Assert-SourceReady (Join-Path $Root 'vendor/core') $p.core.commit (Get-ConsolePatch $Root $p)},{Assert-BuildReady $Root $p},{Assert-DataReady $Root $p})) {try{& $check}catch{$failures.Add($_.Exception.Message)}}
        foreach($f in @('runtime/database.json','runtime/certs/server.crt','runtime/certs/server.key')){if(!(Test-Path (Join-Path $Root $f))){$failures.Add("Not prepared: $f")}}
        if($failures.Count){foreach($f in $failures){Write-Host "OPEN: $f"};exit 2}
        Write-Host 'Files/build metadata are ready. Windows launch and gameplay are separate checks.';exit 0
    }
    Assert-Windows
    Import-Module NetTCPIP
    $s=Read-LocalSettings $Root
    if($Action -in @('Stop','Console')) {
        $state=Read-SupervisorState $Root
        if(!$state){throw 'No live supervisor belongs to this project. No process will be stopped.'}
        $request=@{session=$state.session;action='stop'}
        if($Action -eq 'Console') {
            if(!$Command){$Command=Read-Host 'Worldserver command (for example help or bnetaccount create EMAIL PASSWORD)'}
            if(!$Command -or $Command -match '[\r\n\x00]'){throw 'Enter exactly one console command.'}
            $request.action='command';$request.command=$Command
        }
        Write-JsonFile (Join-Path $Root ('runtime/control/'+[guid]::NewGuid()+'.request.json')) $request
        if($Action -eq 'Stop') {
            $deadline=[DateTime]::UtcNow.AddSeconds(180)
            while((Read-SupervisorState $Root) -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 500}
            if(Read-SupervisorState $Root){throw 'Shutdown is still pending. No force kill was performed.'}
            Assert-PortsFree @($p.database.port,$p.ports.bnet,$p.ports.rest,$p.ports.world)
            Write-Host 'Server processes stopped.'
        } else {Write-Host 'Command queued. Verify its result in runtime/logs; queuing is not confirmation of success.'}
        exit 0
    }
    if($Action -eq 'Start'){& (Join-Path $PSScriptRoot 'Supervisor.ps1') -Root $Root;exit 0}
    $lock=[IO.File]::Open((Join-Path $Root 'runtime/instance.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        Assert-PortsFree @($p.database.port,$p.ports.bnet,$p.ports.rest,$p.ports.world)
        switch($Action) {
            Source {Prepare-CoreSource $Root $p}
            Build {Build-Core $Root $p $s}
            DatabaseFiles {Download-Database $Root $p $s}
            Extract {Extract-ClientData $Root $p $s}
            Database {Initialize-Database $Root $p $s}
            Certificates {New-ServerCertificates $Root $p $s}
            Backup {
                Require-File (Join-Path $Root 'runtime/database.json')
                $dest=Copy-OfflineSnapshot $Root
                Write-Host "Offline backup: $dest"
            }
        }
    } finally {$lock.Dispose()}
} catch {Write-Error $_;exit 1}
