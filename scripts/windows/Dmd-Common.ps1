# Shared helpers for building and running the dmd simulator on Windows.

$ErrorActionPreference = 'Stop'

$DmdAppOrder = @('dmd_common', 'wme', 'dmd_agent', 'dmd_mgmt')

function Resolve-DmdRoot {
    param(
        [string]$StartDir = $PSScriptRoot
    )

    $startDir = (Resolve-Path -LiteralPath $StartDir).Path

    if (Test-Path -LiteralPath (Join-Path $startDir 'lib\dmd_common\ebin')) {
        return @{
            Root = $startDir
            Mode = 'Dist'
        }
    }

    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $startDir '..\..')).Path
    if (Test-Path -LiteralPath (Join-Path $repoRoot 'rebar.config')) {
        return @{
            Root = $repoRoot
            Mode = 'Dev'
        }
    }

    throw "Cannot resolve dmd simulator root from $StartDir"
}

function Get-DmdEbinPaths {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Dist')]
        [string]$Mode
    )

    $paths = @()
    foreach ($app in $DmdAppOrder) {
        if ($Mode -eq 'Dist') {
            $path = Join-Path $Root "lib\$app\ebin"
        }
        else {
            $path = Join-Path $Root "_build\default\lib\$app\ebin"
        }

        if (-not (Test-Path -LiteralPath $path)) {
            throw "Missing compiled app ebin: $path`nRun Build-WindowsDistribution.ps1 or rebar3 compile first."
        }

        $paths += $path
    }

    return $paths
}

function Test-DmdPrerequisites {
    $missing = @()

    if (-not (Get-Command erl -ErrorAction SilentlyContinue)) {
        $missing += 'erl (Erlang/OTP for Windows x64 — https://www.erlang.org/downloads)'
    }

    if (-not (Get-Command rebar3 -ErrorAction SilentlyContinue)) {
        $missing += 'rebar3 (https://www.rebar3.org — required for build/compile from source)'
    }

    if ($missing.Count -gt 0) {
        throw "Missing prerequisites:`n  - $($missing -join "`n  - ")"
    }

    $version = & erl -noshell -eval "io:format(""~s"", [erlang:system_info(otp_release)]), halt()." 2>&1
    Write-Host "Erlang/OTP release: $version"
}

function Test-DmdPrerequisitesRuntime {
    if (-not (Get-Command erl -ErrorAction SilentlyContinue)) {
        throw 'erl is not on PATH. Install Erlang/OTP for Windows x64 (https://www.erlang.org/downloads).'
    }
}

function Invoke-DmdCompile {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    if (-not (Get-Command rebar3 -ErrorAction SilentlyContinue)) {
        throw 'rebar3 is not on PATH. Install rebar3 or run from a staged dist/windows-x64 folder.'
    }

    Write-Host ">> Compiling in $Root ..."
    Push-Location $Root
    try {
        & rebar3 compile
        if ($LASTEXITCODE -ne 0) {
            throw "rebar3 compile failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Ensure-DmdLogDir {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $logDir = Join-Path $Root 'log'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
}

function Get-DmdDeviceCsvPath {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [string]$CsvPath
    )

    if ($CsvPath) {
        return (Resolve-Path -LiteralPath $CsvPath).Path
    }

    $default = Join-Path $Root 'config\devices.csv'
    if (-not (Test-Path -LiteralPath $default)) {
        throw "Device CSV not found: $default"
    }

    return $default
}

function Get-DmdDeviceIps {
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath
    )

    return Import-Csv -LiteralPath $CsvPath |
        ForEach-Object { $_.IP.Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique
}

function Test-DmdLoopbackIp {
    param(
        [Parameter(Mandatory)]
        [string]$Ip
    )

    if (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue) {
        return $null -ne (Get-NetIPAddress -AddressFamily IPv4 -IPAddress $Ip -ErrorAction SilentlyContinue)
    }

    $output = & netsh interface ipv4 show addresses 2>&1
    return ($output -join "`n") -match [regex]::Escape($Ip)
}

function Test-DmdLoopbackAliases {
    param(
        [Parameter(Mandatory)]
        [string[]]$Ips
    )

    $missing = @()
    foreach ($ip in $Ips) {
        if (-not (Test-DmdLoopbackIp -Ip $ip)) {
            $missing += $ip
        }
    }

    return $missing
}

function Get-DmdLoopbackInterfaceName {
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        $adapter = Get-NetAdapter |
            Where-Object { $_.InterfaceDescription -like '*Loopback*' -or $_.Name -like '*Loopback*' } |
            Select-Object -First 1
        if ($adapter) {
            return $adapter.Name
        }
    }

    return 'Loopback Pseudo-Interface 1'
}

function Start-DmdNode {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Dist')]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string[]]$EvalStatements,

        [string]$ConfigBase = 'sys'
    )

    Test-DmdPrerequisitesRuntime
    Ensure-DmdLogDir -Root $Root

    $ebinPaths = Get-DmdEbinPaths -Root $Root -Mode $Mode
    $configPath = Join-Path $Root "config\$ConfigBase"

    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Config not found: $configPath"
    }

    Push-Location $Root
    try {
        $erlArgs = @()
        foreach ($path in $ebinPaths) {
            $erlArgs += '-pa'
            $erlArgs += $path
        }
        $erlArgs += '-config'
        $erlArgs += $configPath
        $erlArgs += '-eval'
        $erlArgs += ($EvalStatements -join ', ')

        Write-Host ">> Starting Erlang node in $Root (Ctrl+C twice to stop) ..."
        & erl @erlArgs
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            throw "erl exited with code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
