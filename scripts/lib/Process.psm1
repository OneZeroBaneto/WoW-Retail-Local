# SPDX-License-Identifier: GPL-2.0-or-later
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert-PortsFree([int[]]$Ports) {
    $listeners=[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    foreach ($port in $Ports) {
        if (@($listeners | Where-Object Port -eq $port).Count) { throw "Port $port is occupied. Stop the other installation first; no process was terminated." }
    }
}
function Start-OwnedProcess([string]$File,[string[]]$Arguments,[string]$Directory,[string]$LogPrefix) {
    $info=[Diagnostics.ProcessStartInfo]::new($File)
    $info.UseShellExecute=$false; $info.WorkingDirectory=$Directory
    $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    foreach ($arg in $Arguments) { $info.ArgumentList.Add($arg) }
    $p=[Diagnostics.Process]::new(); $p.StartInfo=$info
    $stdout=[IO.FileStream]::new("$LogPrefix.out.log",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
    $stderr=[IO.FileStream]::new("$LogPrefix.err.log",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
    try {
        if (!$p.Start()) { throw "Could not start $File" }
        $outTask=$p.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errTask=$p.StandardError.BaseStream.CopyToAsync($stderr)
        return [pscustomobject]@{ Process=$p; Output=$stdout; Error=$stderr; OutputTask=$outTask; ErrorTask=$errTask; LogPrefix=$LogPrefix }
    } catch { $stdout.Dispose(); $stderr.Dispose(); $p.Dispose(); throw }
}
function Send-OwnedInput($Job,[string]$Command) {
    if ($Command -match '[\r\n\x00]') { throw 'Only one console command per request is accepted.' }
    if ($Job.Process.HasExited) { throw 'Owned process has exited.' }
    $Job.Process.StandardInput.WriteLine($Command); $Job.Process.StandardInput.Flush()
}
function Complete-OwnedProcess($Job,[int]$TimeoutSeconds=120) {
    if (!$Job.Process.WaitForExit($TimeoutSeconds*1000)) { throw "Process did not stop. It was NOT force killed. Inspect $($Job.LogPrefix)." }
    [void]$Job.OutputTask.GetAwaiter().GetResult(); [void]$Job.ErrorTask.GetAwaiter().GetResult()
    $code=$Job.Process.ExitCode
    $Job.Output.Dispose(); $Job.Error.Dispose(); $Job.Process.Dispose()
    return $code
}
function Wait-OwnedPort($Job,[int]$Port,[int]$TimeoutSeconds=120) {
    if (!$IsWindows) { throw 'Owned listener verification requires Windows.' }
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Job.Process.HasExited) { throw "Server exited before port $Port became ready. See $($Job.LogPrefix)." }
        $listeners=@(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
        if ($listeners.Count) {
            if (@($listeners | Where-Object { $_.OwningProcess -ne $Job.Process.Id -or $_.LocalAddress -ne '127.0.0.1' }).Count) { throw "Port $Port belongs to another process/address." }
            return
        }
        Start-Sleep -Milliseconds 300
    }
    throw "Timed out waiting for port $Port; check $($Job.LogPrefix)."
}
function Read-SupervisorState([string]$Root) {
    $path=Join-Path $Root 'runtime/control/supervisor.json'
    if (!(Test-Path $path)) { return $null }
    $state=Get-Content $path -Raw | ConvertFrom-Json
    $p=Get-Process -Id $state.pid -ErrorAction SilentlyContinue
    if (!$p -or $p.StartTime.ToUniversalTime().Ticks.ToString() -ne $state.started) { return $null }
    return $state
}
Export-ModuleMember -Function *
