#Requires -Version 5.1
<#
.SYNOPSIS
Collects read-only model and WMI metadata for JiaoLongOnArch.

.DESCRIPTION
The script does not invoke MICommonInterface.MiInterface, install a driver,
read firmware control values, or change any setting. Serial numbers, UUIDs,
MAC addresses, user names, and PNP instance IDs are intentionally excluded.

.PARAMETER ControlCenterPath
Optional path to an official control-center installer or installed directory.
Only file metadata, hashes, version information, and signatures are recorded;
no proprietary file is copied into the report.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ControlCenterPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$reportDir = Join-Path $desktop "JiaoLongOnArch-Probe-$timestamp"
$zipPath = "$reportDir.zip"
$errors = New-Object System.Collections.Generic.List[string]

New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] $Value
    )

    $path = Join-Path $reportDir $Name
    ConvertTo-Json -InputObject $Value -Depth 8 |
        Set-Content -LiteralPath $path -Encoding UTF8
}

function Invoke-Collection {
    param(
        [Parameter(Mandatory = $true)] [string]$Label,
        [Parameter(Mandatory = $true)] [scriptblock]$Action
    )

    try {
        & $Action
    }
    catch {
        $errors.Add("${Label}: $($_.Exception.Message)")
        $null
    }
}

$system = Invoke-Collection 'Win32_ComputerSystem' {
    Get-CimInstance -ClassName Win32_ComputerSystem |
        Select-Object Manufacturer, Model, SystemType
}

$product = Invoke-Collection 'Win32_ComputerSystemProduct' {
    Get-CimInstance -ClassName Win32_ComputerSystemProduct |
        Select-Object Vendor, Name, Version
}

$baseboard = Invoke-Collection 'Win32_BaseBoard' {
    Get-CimInstance -ClassName Win32_BaseBoard |
        Select-Object Manufacturer, Product, Version
}

$bios = Invoke-Collection 'Win32_BIOS' {
    Get-CimInstance -ClassName Win32_BIOS |
        Select-Object Manufacturer, SMBIOSBIOSVersion, Version, ReleaseDate
}

$operatingSystem = Invoke-Collection 'Win32_OperatingSystem' {
    Get-CimInstance -ClassName Win32_OperatingSystem |
        Select-Object Caption, Version, BuildNumber, OSArchitecture
}

$processors = Invoke-Collection 'Win32_Processor' {
    @(Get-CimInstance -ClassName Win32_Processor |
        Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors)
}

$graphics = Invoke-Collection 'Win32_VideoController' {
    @(Get-CimInstance -ClassName Win32_VideoController |
        Select-Object Name, AdapterCompatibility, DriverVersion, VideoProcessor)
}

Write-JsonFile 'machine.json' ([ordered]@{
    collectedAt = (Get-Date).ToString('o')
    powershell = $PSVersionTable.PSVersion.ToString()
    system = $system
    product = $product
    baseboard = $baseboard
    bios = $bios
    operatingSystem = $operatingSystem
    processors = $processors
    graphics = $graphics
})

$wmiClasses = @()
foreach ($className in @('MICommonInterface', 'HID_EVENT20', 'HID_EVENT21', 'HID_EVENT22', 'HID_EVENT23')) {
    $entry = [ordered]@{
        namespace = 'root/WMI'
        className = $className
        present = $false
        methods = @()
        properties = @()
        instances = @()
        error = $null
    }

    try {
        $class = Get-CimClass -Namespace 'root/WMI' -ClassName $className
        $entry.present = $true
        $entry.methods = @($class.CimClassMethods |
            ForEach-Object { $_.Name } |
            Sort-Object)
        $entry.properties = @($class.CimClassProperties |
            ForEach-Object { $_.Name } |
            Sort-Object)
        $entry.instances = @(Get-CimInstance -Namespace 'root/WMI' -ClassName $className |
            Select-Object InstanceName, Active)
    }
    catch {
        $entry.error = $_.Exception.Message
    }

    $wmiClasses += [pscustomobject]$entry
}
Write-JsonFile 'wmi-classes.json' $wmiClasses

$matchingServices = Invoke-Collection 'Win32_Service' {
    @(Get-CimInstance -ClassName Win32_Service |
        Where-Object {
            $_.Name -match 'Mechrevo|JiaoLong|Control.?Center|Gaming.?Center|Tongfang|Uniwill|MIFS' -or
            $_.DisplayName -match 'Mechrevo|JiaoLong|Control.?Center|Gaming.?Center|Tongfang|Uniwill|MIFS' -or
            $_.PathName -match 'Mechrevo|JiaoLong|Control.?Center|Gaming.?Center|Tongfang|Uniwill|MIFS'
        } |
        Select-Object Name, DisplayName, State, StartMode, PathName)
}
Write-JsonFile 'matching-services.json' @($matchingServices)

$matchingDevices = Invoke-Collection 'Win32_PnPEntity' {
    @(Get-CimInstance -ClassName Win32_PnPEntity |
        Where-Object {
            $_.Name -match 'Mechrevo|JiaoLong|Tongfang|Uniwill|MIFS|ACPI WMI' -or
            $_.Manufacturer -match 'Mechrevo|Tongfang|Uniwill|Bitland'
        } |
        Select-Object Name, Manufacturer, Status, PNPClass)
}
Write-JsonFile 'matching-devices.json' @($matchingDevices)

$installedApps = @()
foreach ($uninstallPath in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)) {
    $items = Invoke-Collection "Registry $uninstallPath" {
        @(Get-ItemProperty -Path $uninstallPath |
            Where-Object {
                $displayName = $_.PSObject.Properties['DisplayName']
                $null -ne $displayName -and
                    $displayName.Value -match 'Mechrevo|JiaoLong|Control.?Center|Gaming.?Center|Tongfang|Uniwill'
            } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation)
    }
    if ($null -ne $items) {
        $installedApps += $items
    }
}
Write-JsonFile 'matching-applications.json' @($installedApps)

$controlCenterFiles = @()
if ($ControlCenterPath) {
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $ControlCenterPath).Path
        $files = if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
            Get-ChildItem -LiteralPath $resolvedPath -Recurse -File |
                Where-Object { $_.Extension -in @('.exe', '.dll', '.sys', '.msi') }
        }
        else {
            @(Get-Item -LiteralPath $resolvedPath)
        }

        foreach ($file in $files) {
            $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
            $version = $file.VersionInfo
            $controlCenterFiles += [pscustomobject]@{
                name = $file.Name
                relativePath = if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
                    $file.FullName.Substring($resolvedPath.Length).TrimStart('\\')
                } else {
                    $file.Name
                }
                length = $file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                productName = $version.ProductName
                productVersion = $version.ProductVersion
                fileVersion = $version.FileVersion
                signatureStatus = $signature.Status.ToString()
                signerSubject = if ($null -ne $signature.SignerCertificate) {
                    $signature.SignerCertificate.Subject
                } else {
                    $null
                }
            }
        }
    }
    catch {
        $errors.Add("ControlCenterPath: $($_.Exception.Message)")
    }
}
Write-JsonFile 'control-center-files.json' @($controlCenterFiles)

$notice = @'
This archive was generated by JiaoLongOnArch/tools/collect-windows.ps1.

The collector is read-only with respect to firmware: it does not invoke
MICommonInterface.MiInterface and does not change fan, performance, RGB,
or GPU/MUX state. It intentionally excludes serial numbers, UUIDs, MAC
addresses, user names, and PNP instance IDs.

If you supplied ControlCenterPath, the archive contains metadata and hashes
only. It does not contain the installer or installed proprietary binaries.
Please provide the original installer separately when you have permission to
do so.
'@
$notice | Set-Content -LiteralPath (Join-Path $reportDir 'README.txt') -Encoding UTF8
$errors | Set-Content -LiteralPath (Join-Path $reportDir 'errors.txt') -Encoding UTF8

try {
    Compress-Archive -Path (Join-Path $reportDir '*') -DestinationPath $zipPath -Force
    Remove-Item -LiteralPath $reportDir -Recurse -Force
    Write-Host "Read-only report created: $zipPath" -ForegroundColor Green
}
catch {
    Write-Warning "Could not create ZIP: $($_.Exception.Message)"
    Write-Host "Uncompressed report remains at: $reportDir"
    exit 1
}
