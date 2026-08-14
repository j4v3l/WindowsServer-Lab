#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    Safely initializes only blank data disks declared for a canonical lab VM.
.DESCRIPTION
    Existing partitions are never reformatted or repurposed. Missing declared drives
    are matched to RAW, non-boot disks in SCSI-slot order and formatted as NTFS with
    64 KiB allocation units for server data workloads.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][int]$VmId,
    [string]$DefinitionPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
if (-not $DefinitionPath) { $DefinitionPath = Join-Path $root 'LabConfig\lab.json' }
if (-not $OutputPath) { $OutputPath = Join-Path $root "Reports\data-disks-$VmId.json" }

Import-Module (Join-Path $root 'Modules\WindowsServerLab\WindowsServerLab.psd1') -Force -ErrorAction Stop
$definition = Import-LabDefinition -Path $DefinitionPath
$vm = @($definition.virtualMachines | Where-Object id -eq $VmId)
if ($vm.Count -ne 1) { throw "VM ID $VmId is not unique in the lab definition." }

$declared = if ($vm[0].PSObject.Properties.Name -contains 'dataDisks') { @($vm[0].dataDisks) } else { @() }
$declared = @($declared | Sort-Object { [int]($_.slot -replace '^scsi', '') })

$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    lab = 'asgard'
    vmId = $VmId
    computerName = $env:COMPUTERNAME
    status = 'configured'
    disks = @()
}

try {
    $missing = [Collections.Generic.List[object]]::new()
    foreach ($expected in $declared) {
        $driveLetter = [string]$expected.driveLetter
        $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Ignore
        if ($volume -and ($volume.FileSystem -ne 'NTFS' -or $volume.FileSystemLabel -ne [string]$expected.label)) {
            $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '${driveLetter}:'" -ErrorAction Stop
            $configurationVolume = @(Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = '${driveLetter}:'" -ErrorAction Stop)
            $isProxmoxConfigurationDrive =
                $logicalDisk.DriveType -eq 5 -and
                $volume.FileSystem -eq 'CDFS' -and
                $volume.FileSystemLabel -eq 'config-2' -and
                $configurationVolume.Count -eq 1
            if ($isProxmoxConfigurationDrive) {
                $usedLetters = @(Get-Volume -ErrorAction Stop | Where-Object DriveLetter | ForEach-Object { ([string]$_.DriveLetter).ToUpperInvariant() })
                $relocationLetter = @(90..69 | ForEach-Object { [string][char]$_ } | Where-Object { $_ -notin $usedLetters } | Select-Object -First 1)
                if ($relocationLetter.Count -ne 1) { throw "No unused drive letter is available for the Proxmox configuration drive currently mounted as ${driveLetter}:." }
                if ($PSCmdlet.ShouldProcess("Proxmox configuration drive ${driveLetter}:", "Relocate to $($relocationLetter[0]): so the declared data disk can use ${driveLetter}:")) {
                    Set-CimInstance -InputObject $configurationVolume[0] -Property @{ DriveLetter = "$($relocationLetter[0]):" } -ErrorAction Stop | Out-Null
                }
                if ($WhatIfPreference) {
                    $volume = $null
                }
                else {
                    $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Ignore
                    if ($volume) { throw "Proxmox configuration drive relocation did not release ${driveLetter}:." }
                }
            }
        }
        if ($volume) {
            if ($volume.FileSystem -ne 'NTFS' -or $volume.FileSystemLabel -ne [string]$expected.label) {
                throw "Drive ${driveLetter}: exists but is not the declared NTFS volume '$($expected.label)'; refusing to alter it."
            }
            $minimumBytes = [int64]$expected.sizeGB * 1GB * 0.90
            if ([int64]$volume.Size -lt $minimumBytes) { throw "Drive ${driveLetter}: is smaller than the declared $($expected.sizeGB) GB data disk." }
            $result.disks += [ordered]@{ slot = $expected.slot; driveLetter = $driveLetter; label = $volume.FileSystemLabel; status = 'existing' }
        }
        else {
            $missing.Add($expected)
        }
    }

    $rawDisks = @(Get-Disk -ErrorAction Stop | Where-Object { -not $_.IsBoot -and -not $_.IsSystem -and $_.PartitionStyle -eq 'RAW' } | Sort-Object Number)
    if ($rawDisks.Count -ne $missing.Count) {
        throw "Expected $($missing.Count) blank data disk(s), found $($rawDisks.Count). Refusing ambiguous disk initialization."
    }

    for ($index = 0; $index -lt $missing.Count; $index++) {
        $expected = $missing[$index]
        $disk = $rawDisks[$index]
        $driveLetter = [string]$expected.driveLetter
        $minimumBytes = [int64]$expected.sizeGB * 1GB * 0.90
        if ([int64]$disk.Size -lt $minimumBytes) { throw "Blank disk $($disk.Number) is smaller than declared slot $($expected.slot)." }
        if ($PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Initialize declared $($expected.slot) as ${driveLetter}: ($($expected.label))")) {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT -ErrorAction Stop | Out-Null
            $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter $driveLetter -ErrorAction Stop
            Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel ([string]$expected.label) -AllocationUnitSize 65536 -Confirm:$false -Force -ErrorAction Stop | Out-Null
        }
        if ($WhatIfPreference) {
            $result.status = 'planned'
            $result.disks += [ordered]@{ slot = $expected.slot; driveLetter = $driveLetter; label = $expected.label; status = 'planned' }
            continue
        }
        $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
        if ($volume.FileSystem -ne 'NTFS' -or $volume.FileSystemLabel -ne [string]$expected.label) { throw "Data-disk verification failed for ${driveLetter}:." }
        $result.disks += [ordered]@{ slot = $expected.slot; driveLetter = $driveLetter; label = $volume.FileSystemLabel; status = 'initialized' }
    }
}
catch {
    $result.status = 'failed'
    $result.error = $_.Exception.Message
    throw
}
finally {
    $reportDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $reportDirectory)) { New-Item -Path $reportDirectory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-LabLog -Level $(if ($result.status -eq 'failed') { 'Error' } else { 'Info' }) -Message "Data disk reconciliation $($result.status) for VM $VmId" -Data @{ Lab = 'asgard' }
}

$result
