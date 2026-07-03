#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Apply TCP tuning recommended for large dmd simulator fleets on Windows Server.

.DESCRIPTION
    Expands the ephemeral port range and shortens TIME_WAIT so 10k+ short-lived
    CALL connections are less likely to hit `{error, system_limit}'.

    Run once per machine (reboot recommended afterwards on Server 2016).

.PARAMETER WhatIf
    Show the changes without applying them.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'

function Show-CurrentTcpSettings {
    Write-Host '== Current settings =='
    & netsh int ipv4 show dynamicport tcp
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    foreach ($name in @('MaxUserPort', 'TcpTimedWaitDelay')) {
        $value = (Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue).$name
        if ($null -ne $value) {
            Write-Host "$name = $value"
        }
        else {
            Write-Host "$name = (default)"
        }
    }
}

Show-CurrentTcpSettings

if ($PSCmdlet.ShouldProcess('TCP/IP stack', 'Expand dynamic port range')) {
    Write-Host '>> Setting dynamic TCP port range to 1024-65535 ...'
    & netsh int ipv4 set dynamicport tcp start=1024 num=64512
    if ($LASTEXITCODE -ne 0) {
        throw "netsh set dynamicport failed (exit code $LASTEXITCODE)"
    }
}

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
if (-not (Test-Path -LiteralPath $regPath)) {
    throw "Registry path not found: $regPath"
}

if ($PSCmdlet.ShouldProcess($regPath, 'Set MaxUserPort=65534')) {
    New-ItemProperty -Path $regPath -Name MaxUserPort -PropertyType DWord -Value 65534 -Force | Out-Null
}

if ($PSCmdlet.ShouldProcess($regPath, 'Set TcpTimedWaitDelay=30')) {
    New-ItemProperty -Path $regPath -Name TcpTimedWaitDelay -PropertyType DWord -Value 30 -Force | Out-Null
}

Write-Host ''
Show-CurrentTcpSettings
Write-Host ''
Write-Host 'Done. Reboot Windows Server 2016 after first-time tuning, then run Start-All.ps1 -Scale.'
