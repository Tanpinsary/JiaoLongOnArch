#Requires -Version 5.1
<#
.SYNOPSIS
Reads reviewed MIFS values from an exactly allowlisted Jiaolong MRID6-23.

.DESCRIPTION
Every request is a 32-byte MiInterface GET packet with operation byte 0xFA.
The script contains no SET operation code and refuses to run unless DMI and
BIOS exactly match the reviewed Ryzen 7 7745HX machine. It does not query the
protocol-conflicting MaxFanSpeedSwitch function 20.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expected = [ordered]@{
    SystemManufacturer = 'MECHREVO'
    SystemModel = 'Jiaolong Series MRID6'
    ProductVendor = 'MECHREVO'
    ProductName = 'Jiaolong Series MRID6'
    ProductVersion = '1'
    BoardManufacturer = 'MECHREVO'
    BoardProduct = 'MRID6-23'
    BoardVersion = 'Base Board Version'
    BiosManufacturer = 'INSYDE Corp.'
    BiosVersion = 'MRID6_23_P_V35'
}

$system = Get-CimInstance -ClassName Win32_ComputerSystem
$product = Get-CimInstance -ClassName Win32_ComputerSystemProduct
$board = Get-CimInstance -ClassName Win32_BaseBoard
$bios = Get-CimInstance -ClassName Win32_BIOS
$actual = [ordered]@{
    SystemManufacturer = $system.Manufacturer
    SystemModel = $system.Model
    ProductVendor = $product.Vendor
    ProductName = $product.Name
    ProductVersion = $product.Version
    BoardManufacturer = $board.Manufacturer
    BoardProduct = $board.Product
    BoardVersion = $board.Version
    BiosManufacturer = $bios.Manufacturer
    BiosVersion = $bios.SMBIOSBIOSVersion
}

foreach ($key in $expected.Keys) {
    if ($actual[$key] -ne $expected[$key]) {
        throw "DMI allowlist mismatch for ${key}: expected '$($expected[$key])', got '$($actual[$key])'"
    }
}

$instanceName = 'ACPI\PNP0C14\MIFS_0'
$instances = @(Get-CimInstance -Namespace 'root/WMI' -ClassName MICommonInterface)
$targets = @($instances | Where-Object { $_.InstanceName -eq $instanceName })
if ($targets.Count -ne 1) {
    $names = @($instances | ForEach-Object { $_.InstanceName }) -join ', '
    throw "Expected exactly one MICommonInterface '$instanceName'; found $($targets.Count). Instances: $names"
}
$target = $targets[0]

# Deliberately excludes function 20 because official Jiaolong and Linux upstream
# disagree about its payload layout. These are the GETs used by the official UI.
$functions = [ordered]@{
    8 = 'SystemPerMode'
    9 = 'GPUMode'
    10 = 'RGBKeyboardStatus'
    11 = 'FnLock'
    12 = 'TPLock'
    13 = 'CPUGPUFanSpeed'
    15 = 'Ambientlight'
    16 = 'RGBKeyboardMode'
    17 = 'RGBKeyboardColor'
    18 = 'RGBKeyboardBrightness'
    19 = 'SystemAcType'
    21 = 'MaxFanSpeed'
    22 = 'CPUThermometer'
    23 = 'CPUPower'
}

$results = @()
foreach ($entry in $functions.GetEnumerator()) {
    $functionId = [byte]$entry.Key
    $request = New-Object byte[] 32
    $request[1] = 0xFA # GET only
    $request[3] = $functionId

    $result = [ordered]@{
        functionId = [int]$functionId
        name = [string]$entry.Value
        operation = 'GET'
        requestHex = [BitConverter]::ToString($request)
        success = $false
        outputLength = 0
        outputHex = $null
        outputBytes = @()
        error = $null
    }

    try {
        $response = Invoke-CimMethod -InputObject $target -MethodName MiInterface -Arguments @{
            InData = [byte[]]$request
        }
        $output = [byte[]]$response.OutData
        if ($null -eq $output) {
            throw 'MiInterface returned no OutData'
        }
        $result.success = $true
        $result.outputLength = $output.Length
        $result.outputHex = [BitConverter]::ToString($output)
        $result.outputBytes = @($output | ForEach-Object { [int]$_ })
    }
    catch {
        $result.error = $_.Exception.Message
    }

    $results += [pscustomobject]$result
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$path = Join-Path $desktop "JiaoLongOnArch-MIFS-ReadOnly-$timestamp.json"
$report = [ordered]@{
    collectedAt = (Get-Date).ToString('o')
    safety = 'Exact DMI allowlist; MiInterface GET operation 0xFA only; function 20 excluded'
    dmi = $actual
    instanceName = $target.InstanceName
    active = $target.Active
    results = $results
}
ConvertTo-Json -InputObject $report -Depth 8 |
    Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Read-only MIFS report created: $path" -ForegroundColor Green
