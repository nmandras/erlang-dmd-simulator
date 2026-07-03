#Requires -Version 5.1
<#
.SYNOPSIS
    Start the management server (dmd_mgmt) on Windows.

.PARAMETER Tls
    Use config\sys.tls.config instead of config\sys.config.

.PARAMETER NoCompile
    Skip rebar3 compile when running from a git checkout (dev mode).

.PARAMETER NoLoopbackCheck
    Do not warn about missing 127.10.0.x loopback aliases.
#>

[CmdletBinding()]
param(
    [switch]$Tls,
    [switch]$NoCompile,
    [switch]$NoLoopbackCheck
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Dmd-Common.ps1"

$ctx = Resolve-DmdRoot -StartDir $PSScriptRoot

if ($ctx.Mode -eq 'Dev' -and -not $NoCompile) {
    Invoke-DmdCompile -Root $ctx.Root
}

if (-not $NoLoopbackCheck) {
    $csv = Get-DmdDeviceCsvPath -Root $ctx.Root
    $missing = Test-DmdLoopbackAliases -Ips (Get-DmdDeviceIps -CsvPath $csv)
    if ($missing.Count -gt 0) {
        Write-Warning @"
Missing loopback aliases: $($missing -join ', ')
Run as Administrator: powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\Add-LoopbackAliases.ps1"
"@
    }
}

$configBase = if ($Tls) { 'sys.tls' } else { 'sys' }

Start-DmdNode -Root $ctx.Root -Mode $ctx.Mode -ConfigBase $configBase -EvalStatements @(
    'application:ensure_all_started(dmd_mgmt)'
)
