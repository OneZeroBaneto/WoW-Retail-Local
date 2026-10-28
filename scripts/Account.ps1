#Requires -Version 7.4
param([string]$Email='player@local',[string]$Root=([IO.Directory]::GetParent($PSScriptRoot).FullName))
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/lib/Workspace.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Process.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Windows.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/lib/Readiness.psm1" -DisableNameChecking
Assert-Windows
$p=Read-Profile $Root;$s=Read-LocalSettings $Root
$state=Read-SupervisorState $Root
if(!$state -or !$state.ready){throw 'Start this project and wait for ready before creating an account.'}
$guard=[IO.File]::Open("$Root/local/account.lock",[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    # Validate email before using it in SQL; generated passwords contain only safe hex characters.
    $null=Resolve-PlayerAccountPlan $Email $false $null
    $auth=$p.database.prefix+'_auth'
    $count=[int](Invoke-LocalQuery $Root $s "SELECT COUNT(*) FROM $auth.battlenet_accounts WHERE email='$Email';")
    $path="$Root/local/game-account.json";$saved=$null
    if(Test-Path $path){$saved=Get-Content $path -Raw | ConvertFrom-Json}
    $plan=Resolve-PlayerAccountPlan $Email ($count -gt 0) $saved
    $credentials=$plan.credentials
    if($plan.action -eq 'create') {
        Write-JsonFile $path $credentials
        Write-JsonFile (Join-Path $Root ('runtime/control/'+[guid]::NewGuid()+'.request.json')) @{session=$state.session;action='command';command="bnetaccount create $Email $($credentials.password)"}
    }
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do {
        $rows=Invoke-LocalQuery $Root $s "SELECT COUNT(*) FROM $auth.battlenet_accounts b JOIN $auth.account a ON a.battlenet_account=b.id WHERE b.email='$Email';"
        if([int]$rows -gt 0){break}
        if(!(Read-SupervisorState $Root)){throw 'Server exited during account creation.'}
        Start-Sleep -Milliseconds 300
    }while([DateTime]::UtcNow -lt $deadline)
    if([int]$rows -eq 0){throw 'Core did not create the WoW subaccount. Keep the saved credentials and inspect local world logs.'}
    $body=@{platform_id='Win';program_id='WoW';version=$p.client.version;inputs=@(@{input_id='account_name';value=$Email},@{input_id='password';value=$credentials.password})} | ConvertTo-Json -Depth 5
    $reply=Invoke-RestMethod "https://127.0.0.1:$($p.ports.rest)/bnetserver/login/" -Method Post -ContentType 'application/json' -Body $body -SkipCertificateCheck -TimeoutSec 15
    if($reply.authentication_state -ne 'DONE' -or !$reply.login_ticket){throw 'Account exists but the BNet authentication check failed. No password was reset.'}
    $credentials.status='bnet-auth-verified'
    Write-JsonFile $path $credentials
    Write-Host "Normal account $Email created/verified by the local BNet service."
    Write-Host "Open $path locally to read your generated password. Client world entry still needs to be tested."
}finally{$guard.Dispose()}
