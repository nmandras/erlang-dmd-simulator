#Requires -Version 5.1
<#
.SYNOPSIS
    Start management server and device fleet in one Erlang node on Windows.

.PARAMETER Tls
    Use config\sys.tls.config instead of config\sys.config.

.PARAMETER Scale
    Use config\sys.scale.config, Erlang VM flags for large fleets, and auto-tune
    max_connect_inflight from the device CSV size. Recommended for 1000+ devices
    on Windows Server 2016 after running Set-WindowsTcpTuning.ps1.

.PARAMETER MaxConnectInflight
    Override max_connect_inflight for both apps (only with -Scale).

.PARAMETER NoCompile
    Skip rebar3 compile when running from a git checkout (dev mode).

.PARAMETER NoLoopbackCheck
    Do not warn about missing 127.10.0.x loopback aliases.
#>

[CmdletBinding()]
param(
    [switch]$Tls,
    [switch]$Scale,
    [int]$MaxConnectInflight = 0,
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
        $sample = if ($missing.Count -gt 5) {
            ($missing[0..4] -join ', ') + " ... (+$($missing.Count - 5) more)"
        }
        else {
            $missing -join ', '
        }
        Write-Warning @"
Missing loopback aliases ($($missing.Count)): $sample
The agent cannot bind device listeners until these are added.
Run as Administrator: powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\Add-LoopbackAliases.ps1"
"@
    }
}

$configBase = if ($Tls) { 'sys.tls' } elseif ($Scale) { 'sys.scale' } else { 'sys' }

$csv = Get-DmdDeviceCsvPath -Root $ctx.Root
$vmArgs = @()
$eval = @(
    'application:ensure_all_started(dmd_mgmt)',
    'application:ensure_all_started(dmd_agent)'
)

if ($Scale) {
    $deviceCount = Get-DmdDeviceCount -CsvPath $csv
    $inflight = if ($MaxConnectInflight -gt 0) {
        $MaxConnectInflight
    }
    else {
        Get-DmdScaleInflight -DeviceCount $deviceCount
    }
    $vmArgs = Get-DmdScaleVmArgs
    $eval = Get-DmdScaleEval -Inflight $inflight -StartApps @('dmd_mgmt', 'dmd_agent')
    Write-Host ">> Scale mode: $deviceCount devices, max_connect_inflight=$inflight"
    Write-Host '>> VM flags:' ($vmArgs -join ' ')
    if (-not $NoLoopbackCheck -and $deviceCount -gt 100) {
        Write-Host '>> Tip: run Set-WindowsTcpTuning.ps1 (elevated) once before large fleets.'
    }
}

Start-DmdNode -Root $ctx.Root -Mode $ctx.Mode -ConfigBase $configBase -VmArgs $vmArgs -EvalStatements $eval
