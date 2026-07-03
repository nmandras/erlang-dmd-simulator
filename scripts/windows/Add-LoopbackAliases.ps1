#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Add loopback aliases for device IPs listed in config/devices.csv.

.DESCRIPTION
    The default device CSV binds simulators to 127.10.0.x addresses. Windows
    only has 127.0.0.1 by default, so each extra address must be added to the
    loopback interface before the agent can listen on those ports.

.PARAMETER CsvPath
    Path to devices.csv. Defaults to config\devices.csv under the repo or dist root.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Dmd-Common.ps1"

$ctx = Resolve-DmdRoot -StartDir $PSScriptRoot
$csv = Get-DmdDeviceCsvPath -Root $ctx.Root -CsvPath $CsvPath
$ips = @(Get-DmdDeviceIps -CsvPath $csv)

if ($ips.Count -eq 0) {
    Write-Warning "No IPs found in $csv"
    return
}

$iface = Get-DmdLoopbackInterfaceName
Write-Host "Loopback interface: $iface"
Write-Host "Device IPs in CSV: $($ips -join ', ')"

$missing = Test-DmdLoopbackAliases -Ips $ips
if ($missing.Count -eq 0) {
    Write-Host 'All device loopback aliases are already present.'
    return
}

foreach ($ip in $missing) {
    if ($PSCmdlet.ShouldProcess($ip, "Add loopback alias on $iface")) {
        Write-Host ">> Adding $ip ..."
        & netsh interface ipv4 add address $iface $ip 255.255.255.255
        if ($LASTEXITCODE -ne 0) {
            throw "netsh failed to add $ip (exit code $LASTEXITCODE)"
        }
    }
}

Write-Host 'Done.'
