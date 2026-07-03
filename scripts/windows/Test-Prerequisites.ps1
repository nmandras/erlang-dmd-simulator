#Requires -Version 5.1
<#
.SYNOPSIS
    Verify Erlang/OTP and rebar3 are installed and on PATH.
#>

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Dmd-Common.ps1"

$ctx = Resolve-DmdRoot -StartDir $PSScriptRoot
if ($ctx.Mode -eq 'Dist') {
    Test-DmdPrerequisitesRuntime
}
else {
    Test-DmdPrerequisites
}
Write-Host 'Prerequisites OK.'
