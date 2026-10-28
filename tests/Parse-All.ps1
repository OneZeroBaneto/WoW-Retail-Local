#Requires -Version 7.4
Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$count=0
foreach($file in Get-ChildItem (Join-Path $repo 'scripts'),$PSScriptRoot -Recurse -File | Where-Object Extension -in @('.ps1','.psm1')) {
    $tokens=$null;$errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw "$($file.FullName): $($errors -join '; ')"}
    $count++
}
Write-Host "$count PowerShell files parsed successfully."
