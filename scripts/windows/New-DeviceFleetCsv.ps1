#Requires -Version 5.1
<#
.SYNOPSIS
    Generate a device fleet CSV (wrapper around generate_devices.escript).

.PARAMETER Wmr
    Number of WMR devices (DeviceType 1).

.PARAMETER Wme
    Number of WME devices (DeviceType 2).

.PARAMETER OutputPath
    Destination CSV. Default: config\devices.csv under repo or dist root.

.PARAMETER Reptime
    CALL period in seconds. Default: 10.

.PARAMETER MgmtPort
    Device listen port. Default: 6000.

.PARAMETER StartImei
    First 15-digit IMEI. Default: 101000000000001.

.PARAMETER BaseIp
    Starting IPv4 address. Default: 127.10.0.1

.PARAMETER Force
    Overwrite an existing output file.

.EXAMPLE
    .\New-DeviceFleetCsv.ps1 -Wmr 0 -Wme 10 -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Wmr,

    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Wme,

    [string]$OutputPath,
    [int]$Reptime = 10,
    [int]$MgmtPort = 6000,
    [long]$StartImei = 101000000000001,
    [string]$BaseIp = '127.10.0.1',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Resolve-DmdRoot {
    param([string]$StartDir = $PSScriptRoot)

    if (Test-Path -LiteralPath (Join-Path $StartDir 'lib\dmd_common\ebin')) {
        return $StartDir
    }

    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $StartDir '..\..')).Path
    if (Test-Path -LiteralPath (Join-Path $repoRoot 'rebar.config')) {
        return $repoRoot
    }

    return (Get-Location).Path
}

function Find-GenerateDevicesScript {
    param([string]$Root)

    $candidates = @(
        (Join-Path $Root 'generate_devices.escript'),
        (Join-Path $Root 'scripts\generate_devices.escript'),
        (Join-Path $PSScriptRoot 'generate_devices.escript'),
        (Join-Path $PSScriptRoot '..\generate_devices.escript')
    )

    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }

    throw 'generate_devices.escript not found (re-copy dist or run from repo).'
}

function Find-DmdCommonEbin {
    param([string]$Root)

    $candidates = @(
        (Join-Path $Root 'lib\dmd_common\ebin'),
        (Join-Path $Root '_build\default\lib\dmd_common\ebin')
    )

    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }

    return $null
}

if ($Wmr + $Wme -lt 1) {
    throw 'At least one device is required (Wmr + Wme must be >= 1).'
}

$root = Resolve-DmdRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $root 'config\devices.csv'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $root $OutputPath
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    throw "Output file already exists: $OutputPath (use -Force to overwrite)."
}

$escriptArgs = @(
    $Wmr,
    $Wme,
    '-o', $OutputPath,
    '--reptime', $Reptime,
    '--mgmt-port', $MgmtPort,
    '--start-imei', $StartImei,
    '--base-ip', $BaseIp
)

$script = Find-GenerateDevicesScript -Root $root

if (Get-Command escript -ErrorAction SilentlyContinue) {
    & escript $script @escriptArgs
    if ($LASTEXITCODE -ne 0) {
        throw "generate_devices.escript failed with exit code $LASTEXITCODE"
    }
}
else {
    $ebin = Find-DmdCommonEbin -Root $root
    if (-not $ebin) {
        throw 'escript not on PATH and dmd_common ebin not found.'
    }

    $erlPath = ($OutputPath -replace '\\', '/')
    $baseIpErl = $BaseIp
    $eval = @(
        "Opts = #{start_imei => $StartImei, base_ip => {$($BaseIp -replace '\.', ', ')}, mgmt_port => $MgmtPort, period_sec => $Reptime},",
        "ok = dmd_csv:generate_file(`"$erlPath`", $Wmr, $Wme, Opts),",
        'halt(0).'
    ) -join ' '

    & erl -noshell -pa $ebin -eval $eval
    if ($LASTEXITCODE -ne 0) {
        throw "erl generate failed with exit code $LASTEXITCODE"
    }
}

if ($BaseIp -like '127.*') {
    Write-Host '   Tip: run Add-LoopbackAliases.ps1 (elevated) before starting the agent on Windows.'
}
