#Requires -RunAsAdministrator
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$OutputPath = 'C:\ProgramData\WindowsServerLab\Reports\client-security-baseline.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$result = [ordered]@{
    schemaVersion = 1
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    computerName = $env:COMPUTERNAME
    status = 'planned'
    verified = @()
}

try {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Apply and verify the Windows client lab security baseline')) {
        Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction Stop
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null
        Set-SmbClientConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Confirm:$false -ErrorAction Stop
        Set-SmbServerConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Confirm:$false -ErrorAction Stop
        $registry = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'; Name = 'EnableScriptBlockLogging'; Value = 1 },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'; Name = 'EnableModuleLogging'; Value = 1 },
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'SMB1'; Value = 0 },
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RunAsPPL'; Value = 1 }
        )
        foreach ($setting in $registry) {
            if (-not (Test-Path -LiteralPath $setting.Path)) { New-Item -Path $setting.Path -Force | Out-Null }
            New-ItemProperty -LiteralPath $setting.Path -Name $setting.Name -PropertyType DWord -Value $setting.Value -Force -ErrorAction Stop | Out-Null
            $actual = Get-ItemPropertyValue -LiteralPath $setting.Path -Name $setting.Name -ErrorAction Stop
            if ($actual -ne $setting.Value) { throw "Registry verification failed for $($setting.Path)\$($setting.Name)." }
            $result.verified += "$($setting.Path)\$($setting.Name)"
        }
        Set-MpPreference -DisableRealtimeMonitoring $false -PUAProtection Enabled -ErrorAction Stop
        auditpol.exe /set /subcategory:'Process Creation' /success:enable /failure:enable | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to configure process-creation auditing.' }
        wevtutil.exe sl Security /ms:201326592
        if ($LASTEXITCODE -ne 0) { throw 'Unable to resize the Security event log.' }
        $result.status = 'configured'
    }
}
catch {
    $result.status = 'failed'
    $result.error = $_.Exception.Message
    throw
}
finally {
    $directory = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -Path $directory -ItemType Directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

$result
