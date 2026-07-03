#Requires -Version 5.1
<#
.SYNOPSIS
    Compile and stage a self-contained Windows x64 distribution.

.DESCRIPTION
    Runs rebar3 compile, copies BEAM files and config into dist\windows-x64,
    and copies PowerShell launchers. Requires Erlang/OTP and rebar3 on PATH.

.PARAMETER OutDir
    Output directory. Defaults to dist\windows-x64 under the repository root.

.PARAMETER SkipCompile
    Stage existing _build output without running rebar3 compile.
#>

[CmdletBinding()]
param(
    [string]$OutDir,
    [switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Dmd-Common.ps1"

$ctx = Resolve-DmdRoot -StartDir $PSScriptRoot
$root = $ctx.Root

if (-not $OutDir) {
    $OutDir = Join-Path $root 'dist\windows-x64'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir = Join-Path $root $OutDir
}

Test-DmdPrerequisites

if (-not $SkipCompile) {
    Invoke-DmdCompile -Root $root
}

Write-Host ">> Staging into $OutDir ..."

if (Test-Path -LiteralPath $OutDir) {
    Remove-Item -LiteralPath $OutDir -Recurse -Force
}

$configDir = Join-Path $OutDir 'config'
$logDir = Join-Path $OutDir 'log'
New-Item -ItemType Directory -Path $configDir, $logDir -Force | Out-Null

foreach ($app in $DmdAppOrder) {
    $src = Join-Path $root "_build\default\lib\$app\ebin"
    $dest = Join-Path $OutDir "lib\$app\ebin"
    if (-not (Test-Path -LiteralPath $src)) {
        throw "Missing $src — compile failed?"
    }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $src '*') -Destination $dest -Force
}

Copy-Item -LiteralPath (Join-Path $root 'config\sys.config') -Destination $configDir -Force
Copy-Item -LiteralPath (Join-Path $root 'config\sys.scale.config') -Destination $configDir -Force
Copy-Item -LiteralPath (Join-Path $root 'config\devices.csv') -Destination $configDir -Force
$tlsConfig = Join-Path $root 'config\sys.tls.config'
if (Test-Path -LiteralPath $tlsConfig) {
    Copy-Item -LiteralPath $tlsConfig -Destination $configDir -Force
}

$certsSrc = Join-Path $root 'priv\certs'
if (Test-Path -LiteralPath $certsSrc) {
    $certsDest = Join-Path $OutDir 'priv\certs'
    New-Item -ItemType Directory -Path $certsDest -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $certsSrc '*') -Destination $certsDest -Force
}

$launcherNames = @(
    'Dmd-Common.ps1',
    'Start-All.ps1',
    'Start-Mgmt.ps1',
    'Start-Agent.ps1',
    'Add-LoopbackAliases.ps1',
    'Set-WindowsTcpTuning.ps1',
    'New-DeviceFleetCsv.ps1',
    'generate_devices.bat',
    'Test-Prerequisites.ps1'
)
foreach ($name in $launcherNames) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $OutDir -Force
}

Copy-Item -LiteralPath (Join-Path $root 'scripts\generate_devices.escript') -Destination $OutDir -Force

$readme = @"
dmd simulator - Windows x64 distribution
========================================

Requires Erlang/OTP for Windows x64 installed, with "erl" on PATH
(https://www.erlang.org/downloads).

Before first run, add loopback aliases for device IPs (elevated PowerShell):
  powershell -ExecutionPolicy Bypass -File .\Add-LoopbackAliases.ps1

Run:
  powershell -ExecutionPolicy Bypass -File .\Start-All.ps1
  powershell -ExecutionPolicy Bypass -File .\Start-Mgmt.ps1
  powershell -ExecutionPolicy Bypass -File .\Start-Agent.ps1

Or use the legacy .bat launchers: start_all.bat, start_mgmt.bat, start_agent.bat

Logs are written under log\ (agent.log, mgmt.log). Stopping the node
(Ctrl+C, a) flushes a benchmarking report to each log file.

Edit config\sys.config to change ports, the device CSV, the call period,
or to enable TLS (see config\sys.tls.config; copy certs into priv\certs\).
"@

Set-Content -LiteralPath (Join-Path $OutDir 'README.txt') -Value $readme -Encoding UTF8

# Legacy .bat launchers for environments that prefer cmd.exe.
$pa = ($DmdAppOrder | ForEach-Object { '"%ROOT%lib\{0}\ebin"' -f $_ }) -join ' '
$prologue = @(
    '@echo off',
    'setlocal',
    'set "ROOT=%~dp0"',
    'cd /d "%ROOT%"'
) -join "`r`n"

function Write-DmdBatLauncher {
    param(
        [string]$Path,
        [string]$Eval
    )

    $content = @(
        $prologue,
        "erl -pa $pa -config `"%ROOT%config\sys`" ^",
        "    -eval `"$Eval`""
    ) -join "`r`n"
    Set-Content -LiteralPath $Path -Value $content -Encoding ASCII
}

Write-DmdBatLauncher -Path (Join-Path $OutDir 'start_mgmt.bat') -Eval 'application:ensure_all_started(dmd_mgmt).'
Write-DmdBatLauncher -Path (Join-Path $OutDir 'start_agent.bat') -Eval 'application:ensure_all_started(dmd_agent).'
Write-DmdBatLauncher -Path (Join-Path $OutDir 'start_all.bat') -Eval 'application:ensure_all_started(dmd_mgmt), application:ensure_all_started(dmd_agent).'

$zipPath = Join-Path (Split-Path $OutDir -Parent) 'dmd-windows-x64.zip'
if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
    Write-Host ">> Creating $zipPath ..."
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -LiteralPath $OutDir -DestinationPath $zipPath
}

Write-Host ">> Done: $OutDir"
