Set-StrictMode -Version Latest
$script:LabModuleVersion = '2.0.0'

function Write-LabLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Debug', 'Info', 'Warning', 'Error')][string]$Level,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [Parameter()][string]$LogPath = 'C:\ProgramData\WindowsServerLab\Logs\wslab.jsonl',
        [Parameter()][hashtable]$Data
    )

    $secretAssignmentPattern = '(?i)(password|secret|token|credential|product.?key|license.?key)\s*[:=]\s*\S+'
    $productKeyPattern = '\b[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}\b'
    $safeMessage = ($Message -replace $secretAssignmentPattern, '$1=[REDACTED]') -replace $productKeyPattern, '[REDACTED-PRODUCT-KEY]'
    $entry = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        level     = $Level.ToLowerInvariant()
        message   = $safeMessage
        computer  = $env:COMPUTERNAME
        module    = $script:LabModuleVersion
    }
    if ($Data) {
        $safeData = [ordered]@{}
        foreach ($key in $Data.Keys) {
            if ([string]$key -match '(?i)password|secret|token|credential|product.?key|license.?key') {
                $safeData[$key] = '[REDACTED]'
            }
            elseif ($Data[$key] -is [string]) {
                $safeData[$key] = (($Data[$key] -replace $secretAssignmentPattern, '$1=[REDACTED]') -replace $productKeyPattern, '[REDACTED-PRODUCT-KEY]')
            }
            else {
                $safeData[$key] = $Data[$key]
            }
        }
        $entry.data = $safeData
    }

    $directory = Split-Path -Parent $LogPath
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }
    $entry | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $LogPath -Encoding UTF8

    switch ($Level) {
        'Warning' { Write-Warning $safeMessage }
        'Error' { Write-Error $safeMessage -ErrorAction Continue }
        default { Write-Information $safeMessage -InformationAction Continue }
    }
}

function Import-LabDefinition {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string]$Path)

    try {
        $definition = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Unable to read lab definition '$Path': $($_.Exception.Message)"
    }

    if ($definition.schemaVersion -ne 2) { throw 'Lab definition schemaVersion must be 2.' }
    if ($definition.demo -notin @('asgard', 'olympus')) { throw 'Lab definition demo must be asgard or olympus.' }
    if (-not $definition.domain.dnsName -or -not $definition.virtualMachines) { throw 'Lab definition is missing domain or virtualMachines.' }
    $definition
}

function ConvertTo-LabDistinguishedName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]+$')][string]$DomainName)

    (($DomainName.Trim('.') -split '\.') | ForEach-Object { "DC=$_" }) -join ','
}

function Get-LabProfileVirtualMachine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Definition,
        [Parameter(Mandatory)][Alias('Profile')][ValidateSet('smoke', 'core', 'full')][string]$LabProfile
    )

    @($Definition.virtualMachines | Where-Object { $_.profiles -contains $LabProfile } | ForEach-Object {
        $resolved = $_ | Select-Object *
        $override = $null
        if ($_.PSObject.Properties.Name -contains 'profileResourceOverrides') {
            $profileProperty = $_.profileResourceOverrides.PSObject.Properties[$LabProfile]
            if ($profileProperty) { $override = $profileProperty.Value }
        }
        if ($override) {
            $resolved.cores = $override.cores
            $resolved.memoryMB = $override.memoryMB
            $resolved.diskGB = $override.diskGB
            $resolved | Add-Member -NotePropertyName balloonMinimumMB -NotePropertyValue $override.balloonMinimumMB -Force
        }
        elseif (-not ($resolved.PSObject.Properties.Name -contains 'balloonMinimumMB')) {
            $resolved | Add-Member -NotePropertyName balloonMinimumMB -NotePropertyValue ([Math]::Min(2048, [int]$resolved.memoryMB))
        }
        if ($_.PSObject.Properties.Name -contains 'profileNicOverrides') {
            $nicProperty = $_.profileNicOverrides.PSObject.Properties[$LabProfile]
            if ($nicProperty) { $resolved.nics = @($nicProperty.Value) }
        }
        $resolvedDataDisks = @()
        if ($_.PSObject.Properties.Name -contains 'profileDataDiskOverrides') {
            $dataDiskProperty = $_.profileDataDiskOverrides.PSObject.Properties[$LabProfile]
            if ($dataDiskProperty) { $resolvedDataDisks = @($dataDiskProperty.Value) }
        }
        if ($resolvedDataDisks.Count -eq 0 -and $_.PSObject.Properties.Name -contains 'dataDisks') {
            $resolvedDataDisks = @($_.dataDisks)
        }
        $resolved | Add-Member -NotePropertyName dataDisks -NotePropertyValue $resolvedDataDisks -Force
        $resolved
    } | Sort-Object bootOrder, id)
}

function Test-LabConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Definition,
        [Parameter(Mandatory)][Alias('Profile')][ValidateSet('smoke', 'core', 'full')][string]$LabProfile,
        [switch]$ThrowOnFailure
    )

    $selected = @(Get-LabProfileVirtualMachine -Definition $Definition -LabProfile $LabProfile)
    $expected = switch ($LabProfile) { 'smoke' { 6 } 'core' { 7 } default { 30 } }
    $results = [System.Collections.Generic.List[object]]::new()

    $results.Add([pscustomobject]@{ Name = 'ProfileCount'; Passed = ($selected.Count -eq $expected); Evidence = "$($selected.Count)/$expected" })
    $results.Add([pscustomobject]@{ Name = 'UniqueVmIds'; Passed = (@($Definition.virtualMachines.id | Sort-Object -Unique).Count -eq 30); Evidence = 'VM IDs must be unique' })
    $results.Add([pscustomobject]@{ Name = 'UniqueVmNames'; Passed = (@($Definition.virtualMachines.name | Sort-Object -Unique).Count -eq 30); Evidence = 'VM names must be unique' })
    $allAddresses = @($Definition.virtualMachines | ForEach-Object { $_.nics.ipAddress })
    $results.Add([pscustomobject]@{ Name = 'UniqueIpAddresses'; Passed = (@($allAddresses | Sort-Object -Unique).Count -eq $allAddresses.Count); Evidence = 'NIC addresses must be unique' })
    $results.Add([pscustomobject]@{ Name = 'SafeDefaultDomain'; Passed = ($Definition.domain.dnsName -notlike '*.local'); Evidence = $Definition.domain.dnsName })
    $selectedAddresses = @($selected | ForEach-Object { $_.nics.ipAddress })
    $results.Add([pscustomobject]@{ Name = 'SelectedUniqueIpAddresses'; Passed = (@($selectedAddresses | Sort-Object -Unique).Count -eq $selectedAddresses.Count); Evidence = "$LabProfile selected NIC addresses must be unique" })

    if ($ThrowOnFailure -and @($results | Where-Object { -not $_.Passed }).Count -gt 0) {
        $failures = ($results | Where-Object { -not $_.Passed } | ForEach-Object Name) -join ', '
        throw "Lab definition validation failed: $failures"
    }
    $results
}

function Assert-LabAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This operation requires an elevated Administrator session.'
    }
}

function ConvertTo-LabOuComponent {
    param([Parameter(Mandatory)][string]$Name)
    $Name.Replace('\', '\5c').Replace(',', '\,').Replace('+', '\+').Replace('"', '\"').Replace('<', '\<').Replace('>', '\>').Replace(';', '\;').Replace('=', '\=').Trim()
}

function Confirm-LabOrganizationalUnit {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Path)
    $distinguishedName = "OU=$(ConvertTo-LabOuComponent -Name $Name),$Path"
    try {
        Get-ADOrganizationalUnit -Identity $distinguishedName -ErrorAction Stop | Out-Null
    }
    catch {
        if ($_.Exception.GetType().FullName -ne 'Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException') { throw }
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true -ErrorAction Stop | Out-Null
    }
    $distinguishedName
}

function Initialize-LabDirectory {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]$Definition,
        [Parameter(Mandatory)][Security.SecureString]$DefaultUserPassword,
        [switch]$CreatePrivilegedAccounts
    )

    Assert-LabAdministrator
    Import-Module ActiveDirectory -ErrorAction Stop
    $domain = Get-ADDomain -ErrorAction Stop
    if ($domain.DNSRoot -notin @($Definition.domain.dnsName, $Definition.domain.legacyDnsName)) {
        throw "Current domain '$($domain.DNSRoot)' does not match this lab definition."
    }
    $domainDn = ConvertTo-LabDistinguishedName -DomainName $domain.DNSRoot
    if (-not $PSCmdlet.ShouldProcess($domain.DNSRoot, 'Create or reconcile lab OUs, groups, and users')) { return }

    $baseOu = Confirm-LabOrganizationalUnit -Name $Definition.domain.baseOrganizationalUnit -Path $domainDn
    $departmentsOu = Confirm-LabOrganizationalUnit -Name 'Departments' -Path $baseOu
    $groupsOu = Confirm-LabOrganizationalUnit -Name 'Groups' -Path $baseOu
    $serviceAccountsOu = Confirm-LabOrganizationalUnit -Name 'Service Accounts' -Path $baseOu
    $tier0Ou = Confirm-LabOrganizationalUnit -Name 'Tier 0' -Path $baseOu
    $null = Confirm-LabOrganizationalUnit -Name 'Tier 1' -Path $baseOu
    $null = Confirm-LabOrganizationalUnit -Name 'Tier 2' -Path $baseOu
    $serversOu = Confirm-LabOrganizationalUnit -Name 'Servers' -Path $baseOu
    $workstationsOu = Confirm-LabOrganizationalUnit -Name 'Workstations' -Path $baseOu

    $departmentPaths = @{}
    foreach ($department in $Definition.departments) {
        $departmentPaths[$department] = Confirm-LabOrganizationalUnit -Name $department -Path $departmentsOu
        $groupName = 'GG-' + ($department -replace '[^A-Za-z0-9-]', '-')
        if (-not (Get-ADGroup -LDAPFilter "(sAMAccountName=$groupName)" -ErrorAction Stop)) {
            New-ADGroup -Name $groupName -SamAccountName $groupName -GroupScope Global -GroupCategory Security -Path $groupsOu -Description "Members of $department" -ErrorAction Stop | Out-Null
        }
    }

    foreach ($vm in $Definition.virtualMachines) {
        if ($vm.role -notin @('client', 'aiml-client') -or -not $vm.user) { continue }
        $user = $vm.user
        $existing = Get-ADUser -LDAPFilter "(sAMAccountName=$($user.samAccountName))" -ErrorAction Stop
        if (-not $existing) {
            New-ADUser -Name $user.displayName -DisplayName $user.displayName -SamAccountName $user.samAccountName -UserPrincipalName "$($user.samAccountName)@$($domain.DNSRoot)" -Title $user.title -Department $vm.department -Path $departmentPaths[$vm.department] -AccountPassword $DefaultUserPassword -Enabled $true -ChangePasswordAtLogon $true -PasswordNeverExpires $false -ErrorAction Stop
        }
        $groupName = 'GG-' + ($vm.department -replace '[^A-Za-z0-9-]', '-')
        if (-not (Get-ADGroupMember -Identity $groupName -Recursive -ErrorAction Stop | Where-Object SamAccountName -eq $user.samAccountName)) {
            Add-ADGroupMember -Identity $groupName -Members $user.samAccountName -ErrorAction Stop
        }

        if ($CreatePrivilegedAccounts -and $user.privileged) {
            $adminName = "$($user.samAccountName).admin"
            if (-not (Get-ADUser -LDAPFilter "(sAMAccountName=$adminName)" -ErrorAction Stop)) {
                New-ADUser -Name "$($user.displayName) Admin" -DisplayName "$($user.displayName) Admin" -SamAccountName $adminName -UserPrincipalName "$adminName@$($domain.DNSRoot)" -Path $tier0Ou -AccountPassword $DefaultUserPassword -Enabled $true -ChangePasswordAtLogon $true -PasswordNeverExpires $false -Description 'Separate Tier 0 lab administration identity' -ErrorAction Stop
                Add-ADGroupMember -Identity 'Domain Admins' -Members $adminName -ErrorAction Stop
            }
        }
    }

    foreach ($vm in $Definition.virtualMachines | Where-Object role -notin @('client', 'aiml-client')) {
        $computer = Get-ADComputer -Filter "Name -eq '$($vm.name)'" -ErrorAction Stop
        if ($computer -and $computer.DistinguishedName -notlike "*,$serversOu") {
            Move-ADObject -Identity $computer.DistinguishedName -TargetPath $serversOu -ErrorAction Stop
        }
    }

    Write-LabLog -Level Info -Message "Reconciled directory structure for $($Definition.demo)" -Data @{ Domain = $domain.DNSRoot; ServiceAccountsOu = $serviceAccountsOu; WorkstationsOu = $workstationsOu }
}

function Install-LabRole {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][ValidateSet('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server', 'client', 'aiml-client')][string]$Role,
        [Parameter(Mandatory)]$Definition
    )

    Assert-LabAdministrator
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Install and configure role $Role")) { return }

    if ($Role -in @('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server')) {
        Import-Module ServerManager -ErrorAction Stop
    }
    switch ($Role) {
        { $_ -in @('primary-dc', 'secondary-dc') } {
            Install-WindowsFeature AD-Domain-Services, DNS, GPMC -IncludeManagementTools -ErrorAction Stop | Out-Null
            if ($Role -eq 'primary-dc' -and $Definition.features.dhcp) {
                Install-WindowsFeature DHCP -IncludeManagementTools -ErrorAction Stop | Out-Null
            }
        }
        'file-server' {
            Install-WindowsFeature FS-FileServer, FS-Resource-Manager, Print-Server, Windows-Server-Backup -IncludeManagementTools -ErrorAction Stop | Out-Null
            $root = 'D:\Shares'
            if (-not (Test-Path -LiteralPath $root)) { New-Item -Path $root -ItemType Directory -Force | Out-Null }
            foreach ($shareName in @('Departments', 'Tools')) {
                $path = Join-Path $root $shareName
                if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -ItemType Directory -Force | Out-Null }
                if (-not (Get-SmbShare -Name $shareName -ErrorAction Ignore)) {
                    New-SmbShare -Name $shareName -Path $path -FullAccess 'BUILTIN\Administrators' -ReadAccess 'Authenticated Users' -EncryptData $true -FolderEnumerationMode AccessBased -ErrorAction Stop | Out-Null
                }
            }
            if ($Definition.features.aiml) {
                $path = Join-Path $root 'AIMLData'
                if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -ItemType Directory -Force | Out-Null }
                $aimlTrustee = "$($Definition.domain.netbiosName)\GG-Innovation-Forge"
                $aimlTrusteeResolved = $false
                try {
                    $null = [Security.Principal.NTAccount]::new($aimlTrustee).Translate([Security.Principal.SecurityIdentifier])
                    $aimlTrusteeResolved = $true
                }
                catch [Security.Principal.IdentityNotMappedException] { $aimlTrusteeResolved = $false }
                if (-not (Get-SmbShare -Name 'AIMLData' -ErrorAction Ignore)) {
                    New-SmbShare -Name 'AIMLData' -Path $path -FullAccess 'BUILTIN\Administrators' -EncryptData $true -FolderEnumerationMode AccessBased -ErrorAction Stop | Out-Null
                }
                if ($aimlTrusteeResolved) {
                    $shareAccess = Get-SmbShareAccess -Name AIMLData -ErrorAction Stop | Where-Object { $_.AccountName -eq $aimlTrustee -and $_.AccessControlType -eq 'Allow' -and $_.AccessRight -in @('Change', 'Full') }
                    if (-not $shareAccess) { Grant-SmbShareAccess -Name AIMLData -AccountName $aimlTrustee -AccessRight Change -Force -ErrorAction Stop | Out-Null }
                    & icacls.exe $path /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'BUILTIN\Administrators:(OI)(CI)F' "$($aimlTrustee):(OI)(CI)M" | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "Unable to apply the AI/ML NTFS ACL; icacls exited $LASTEXITCODE." }
                }
            }
        }
        'web-server' {
            Install-WindowsFeature Web-Server, Web-Http-Logging, Web-Request-Monitor, Web-Windows-Auth -IncludeManagementTools -ErrorAction Stop | Out-Null
            $health = @{ demo = $Definition.demo; service = 'web'; status = 'healthy'; aiml = [bool]$Definition.features.aiml } | ConvertTo-Json
            Set-Content -LiteralPath 'C:\inetpub\wwwroot\wslab-health.json' -Value $health -Encoding UTF8
        }
        'management-server' {
            Set-Service Wecsvc -StartupType Automatic
            wecutil.exe qc /q | Out-Null
        }
        'aiml-client' {
            foreach ($path in @('C:\AIMLData', 'C:\AIMLData\Models', 'C:\AIMLData\Notebooks')) {
                if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -ItemType Directory -Force | Out-Null }
            }
        }
    }
    Write-LabLog -Level Info -Message "Role $Role reconciled" -Data @{ Role = $Role; Demo = $Definition.demo }
}

function Set-LabDhcpService {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)]$Definition)

    Assert-LabAdministrator
    if (-not $Definition.features.dhcp) { return }
    if (-not (Get-Service NTDS -ErrorAction Ignore)) { throw 'DHCP authorization must run on a configured domain controller.' }
    $clientNetwork = $Definition.networks.client
    if ($clientNetwork.cidr -notmatch '^(?<prefix>\d{1,3}\.\d{1,3}\.\d{1,3})\.0/24$') {
        throw "The v2 DHCP helper currently requires a /24 client network; found $($clientNetwork.cidr)."
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Authorize DHCP and reconcile $($clientNetwork.cidr)")) { return }

    Import-Module DhcpServer -ErrorAction Stop
    $prefix = $Matches.prefix
    $scopeId = "$prefix.0"
    $domain = Get-ADDomain -ErrorAction Stop
    $serverAddress = @($Definition.virtualMachines | Where-Object role -eq 'primary-dc').nics | Where-Object network -eq 'production' | Select-Object -ExpandProperty ipAddress -First 1
    if (-not (Get-DhcpServerInDC -ErrorAction Stop | Where-Object DnsName -eq "$env:COMPUTERNAME.$($domain.DNSRoot)")) {
        Add-DhcpServerInDC -DnsName "$env:COMPUTERNAME.$($domain.DNSRoot)" -IPAddress $serverAddress -ErrorAction Stop
    }
    if (-not (Get-DhcpServerv4Scope -ScopeId $scopeId -ErrorAction Ignore)) {
        Add-DhcpServerv4Scope -Name "$($Definition.displayName) clients" -StartRange "$prefix.100" -EndRange "$prefix.199" -SubnetMask 255.255.255.0 -State Active -ErrorAction Stop
    }
    Set-DhcpServerv4OptionValue -ScopeId $scopeId -Router $clientNetwork.gateway -DnsServer @($clientNetwork.dnsServers) -DnsDomain $domain.DNSRoot -ErrorAction Stop
    Set-Service DHCPServer -StartupType Automatic
    Start-Service DHCPServer
    Write-LabLog -Level Info -Message "Reconciled DHCP scope $scopeId" -Data @{ ScopeId = $scopeId; Start = "$prefix.100"; End = "$prefix.199" }
}

function Set-LabRegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Path, [string]$Name, [ValidateSet('DWord', 'String')][string]$Type, $Value)
    if (-not $PSCmdlet.ShouldProcess("$Path\$Name", "Set registry value to $Value")) { return }
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
}

function Set-LabSecurityBaseline {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][ValidateSet('DomainController', 'MemberServer', 'WorkgroupMember')][string]$ServerRole,
        [string]$SctBaselinePath,
        [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$SctBaselineSha256,
        [switch]$EnableAppControl
    )

    Assert-LabAdministrator
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Apply $ServerRole security baseline")) { return }

    $caption = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
    if ($caption -match '2025') {
        if (-not (Get-Module -ListAvailable Microsoft.OSConfig)) {
            throw 'Microsoft.OSConfig is required for the Windows Server 2025 baseline. Install it from the approved repository before continuing.'
        }
        Import-Module Microsoft.OSConfig -ErrorAction Stop
        Set-OSConfigDesiredConfiguration -Scenario "SecurityBaseline/WindowsServer/2025/$ServerRole" -Default -ErrorAction Stop
        Set-OSConfigDesiredConfiguration -Scenario 'Defender/Antivirus/WindowsServer/2025' -Default -ErrorAction Stop
        Set-OSConfigDesiredConfiguration -Scenario SecuredCore -Default -ErrorAction Stop
        if ($ServerRole -eq 'MemberServer') {
            Set-OSConfigDesiredConfiguration -Scenario 'LAPS/WindowsServer/2025/MemberServer' -Default -ErrorAction Stop
        }
        if ($EnableAppControl) {
            Set-OSConfigDesiredConfiguration -Scenario 'AppControl\WS2025\DefaultPolicy\Audit' -Default -ErrorAction Stop
            Set-OSConfigDesiredConfiguration -Scenario 'AppControl\WS2025\AppBlockList\Audit' -Default -ErrorAction Stop
        }
    }
    elseif ($caption -match '2022') {
        if (-not $SctBaselinePath -or -not $SctBaselineSha256) {
            throw 'Windows Server 2022 requires -SctBaselinePath and -SctBaselineSha256 for the approved Security Compliance Toolkit package.'
        }
        if (-not (Test-Path -LiteralPath $SctBaselinePath -PathType Leaf)) { throw "SCT package not found: $SctBaselinePath" }
        $actual = (Get-FileHash -LiteralPath $SctBaselinePath -Algorithm SHA256 -ErrorAction Stop).Hash
        if ($actual -ne $SctBaselineSha256.ToUpperInvariant()) { throw 'Security Compliance Toolkit package checksum mismatch.' }
        $temporaryPath = Join-Path $env:TEMP ("wslab-sct-{0}" -f ([guid]::NewGuid().ToString('N')))
        try {
            Expand-Archive -LiteralPath $SctBaselinePath -DestinationPath $temporaryPath -Force -ErrorAction Stop
            $lgpo = Get-ChildItem -LiteralPath $temporaryPath -Filter LGPO.exe -File -Recurse -ErrorAction Stop | Select-Object -First 1
            if (-not $lgpo) { throw 'The approved SCT package does not contain LGPO.exe.' }

            $rolePattern = if ($ServerRole -eq 'DomainController') { 'Domain Controller' } else { 'Member Server' }
            $backupInfo = Get-ChildItem -LiteralPath $temporaryPath -Filter bkupInfo.xml -File -Recurse -ErrorAction Stop | Where-Object {
                (Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop) -match $rolePattern
            } | Select-Object -First 1
            if (-not $backupInfo) { throw "No Windows Server 2022 $rolePattern policy backup was found in the approved SCT package." }

            $process = Start-Process -FilePath $lgpo.FullName -ArgumentList @('/g', $backupInfo.Directory.FullName) -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -ne 0) { throw "LGPO.exe failed with exit code $($process.ExitCode)." }
            Set-LabRegistryValue -Path 'HKLM:\SOFTWARE\WindowsServerLab\Baseline' -Name Server2022SctSha256 -Type String -Value $actual
        }
        finally {
            if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction Ignore }
        }
    }
    else {
        throw "Unsupported server version: $caption"
    }

    Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction Stop
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null
    Set-SmbClientConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -Confirm:$false -ErrorAction Stop
    Set-SmbServerConfiguration -RequireSecuritySignature $true -EnableSecuritySignature $true -EncryptData $true -Confirm:$false -ErrorAction Stop
    Set-LabRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -Type DWord -Value 1
    Set-LabRegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -Name EnableTranscripting -Type DWord -Value 1
    Set-LabRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -Type DWord -Value 1
    Set-LabRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Name LDAPServerIntegrity -Type DWord -Value 2
    Set-LabRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Name LdapEnforceChannelBinding -Type DWord -Value 2
    Set-LabRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LDAP' -Name LdapClientIntegrity -Type DWord -Value 2
    Set-LabRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name SMB1 -Type DWord -Value 0
    foreach ($frameworkPath in @('HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319')) {
        Set-LabRegistryValue -Path $frameworkPath -Name SchUseStrongCrypto -Type DWord -Value 1
        Set-LabRegistryValue -Path $frameworkPath -Name SystemDefaultTlsVersions -Type DWord -Value 1
    }
    foreach ($endpoint in @('Client', 'Server')) {
        Set-LabRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\$endpoint" -Name Enabled -Type DWord -Value 0
        Set-LabRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\$endpoint" -Name DisabledByDefault -Type DWord -Value 1
        Set-LabRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\$endpoint" -Name Enabled -Type DWord -Value 1
        Set-LabRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\$endpoint" -Name DisabledByDefault -Type DWord -Value 0
    }
    auditpol.exe /set /subcategory:'Process Creation' /success:enable /failure:enable | Out-Null
    auditpol.exe /set /subcategory:'Credential Validation' /success:enable /failure:enable | Out-Null
    auditpol.exe /set /subcategory:'Account Lockout' /success:enable /failure:enable | Out-Null
    wevtutil.exe sl Security /ms:201326592 | Out-Null
    Write-LabLog -Level Info -Message "Applied security baseline for $ServerRole" -Data @{ ServerRole = $ServerRole; OperatingSystem = $caption }
}

function Test-LabGuestCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('primary-dc', 'secondary-dc', 'file-server', 'web-server', 'management-server', 'client', 'aiml-client')][string]$Role,
        [Parameter(Mandatory)][ValidateSet('infrastructure', 'domain', 'services', 'security', 'full')][string]$Phase
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $add = {
        param($Name, $Required, $Passed, $Evidence, $Remediation)
        $results.Add([pscustomobject]@{ name = $Name; required = $Required; passed = [bool]$Passed; evidence = $Evidence; remediation = $Remediation })
    }

    & $add 'qemu-guest-agent' $true ((Get-Service QEMU-GA -ErrorAction Ignore).Status -eq 'Running') 'QEMU-GA service' 'Install and start QEMU Guest Agent.'

    if ($Phase -in @('domain', 'full')) {
        $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        & $add 'domain-membership' $true ([bool]$computerSystem.PartOfDomain) $computerSystem.Domain 'Complete the domain-join phase.'
        if ($Role -in @('primary-dc', 'secondary-dc')) {
            $dcdiag = & dcdiag.exe /test:Advertising 2>&1
            & $add 'dcdiag-advertising' $true ($LASTEXITCODE -eq 0) ($dcdiag -join '; ') 'Correct Active Directory advertising and DNS registration failures.'
            $repadmin = & repadmin.exe /replsummary 2>&1
            & $add 'replication-summary' $true ($LASTEXITCODE -eq 0) ($repadmin -join '; ') 'Resolve replication errors before certification.'
            $domainName = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).Domain
            $srvRecord = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$domainName" -Type SRV -ErrorAction Ignore
            & $add 'dns-srv-records' $true ([bool]$srvRecord) $domainName 'Repair AD-integrated DNS and rerun registration.'
        }
    }

    if ($Phase -in @('services', 'full')) {
        if ($Role -in @('primary-dc', 'secondary-dc')) {
            & $add 'active-directory-service' $true ((Get-Service NTDS -ErrorAction Ignore).Status -eq 'Running') 'NTDS service' 'Complete domain controller promotion.'
            & $add 'dns-service' $true ((Get-Service DNS -ErrorAction Ignore).Status -eq 'Running') 'DNS service' 'Install and start DNS.'
            if ($Role -eq 'primary-dc' -and (Get-Service DHCPServer -ErrorAction Ignore)) {
                & $add 'dhcp-service' $true ((Get-Service DHCPServer -ErrorAction Ignore).Status -eq 'Running') 'DHCP Server service' 'Authorize and start DHCP.'
                & $add 'dhcp-active-scope' $true (@(Get-DhcpServerv4Scope -ErrorAction Ignore | Where-Object State -eq Active).Count -gt 0) 'Active DHCP scope' 'Run Set-LabDhcpService on the primary DC.'
            }
        }
        if ($Role -eq 'file-server') {
            $share = Get-SmbShare -Name AsgardData -ErrorAction Ignore
            & $add 'asgard-data-share' $true ([bool]$share) 'AsgardData SMB share' 'Run the Asgard file-service phase.'
            & $add 'asgard-data-encryption' $true ([bool]$share.EncryptData) 'SMB encryption setting' 'Enable encryption on AsgardData.'
            & $add 'asgard-data-volume' $true ([bool](Get-Volume -DriveLetter D -ErrorAction Ignore)) 'D: data volume' 'Attach and initialize the declarative file-server data disk.'
            $branding = Get-SmbShare -Name Branding -ErrorAction Ignore
            & $add 'branding-share' $true ([bool]$branding -and [bool]$branding.EncryptData -and (Test-Path -LiteralPath 'D:\Shares\Branding\asgard-wallpaper.bmp')) 'Encrypted read-only branding share and wallpaper' 'Run New-LabAsgardBranding.ps1.'
            & $add 'print-server-role' $true ((Get-WindowsFeature Print-Server -ErrorAction Ignore).InstallState -eq 'Installed') 'Print Server feature' 'Install the Print-Server role. A hardware queue still requires approved device and driver details.'
        }
        if ($Role -eq 'web-server') {
            & $add 'web-health' $true (Test-Path -LiteralPath 'C:\inetpub\wwwroot\wslab-health.json') 'IIS health document' 'Run Install-LabRole for web-server.'
        }
        if ($Role -eq 'management-server') {
            & $add 'event-collector' $true ((Get-Service Wecsvc -ErrorAction Ignore).Status -eq 'Running') 'Wecsvc service' 'Configure Windows Event Collector.'
            $subscription = & wecutil.exe gs WindowsServerLab-Security 2>&1
            & $add 'event-subscription' $true ($LASTEXITCODE -eq 0) ($subscription -join '; ') 'Create the source-initiated WindowsServerLab-Security subscription.'
        }
        if ($Role -eq 'aiml-client') {
            $aimlHealth = 'C:\ProgramData\WindowsServerLab\Reports\olympus-aiml-health.json'
            & $add 'aiml-feature-health' $true (Test-Path -LiteralPath $aimlHealth) 'Pinned toolchain health evidence' 'Install the pinned AI/ML feature manifest and start its health endpoint.'
        }
    }

    if ($Phase -in @('security', 'full')) {
        & $add 'firewall-enabled' $true (@(Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0) 'All profiles must be enabled' 'Enable Domain, Private and Public firewall profiles.'
        & $add 'smb1-disabled' $true ((Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop).State -eq 'Disabled') 'SMB1 feature state' 'Disable SMB1Protocol.'
        & $add 'smb-signing' $true ([bool](Get-SmbServerConfiguration).RequireSecuritySignature) 'Server signing requirement' 'Require SMB signing.'
        & $add 'powershell-script-block-logging' $true ((Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name EnableScriptBlockLogging -ErrorAction Ignore) -eq 1) 'Registry policy' 'Enable PowerShell script block logging.'
        & $add 'defender-realtime-protection' $true (-not [bool](Get-MpPreference -ErrorAction Stop).DisableRealtimeMonitoring) 'Microsoft Defender preference' 'Enable Defender real-time protection.'
        & $add 'security-log-size' $true ([int64]((Get-WinEvent -ListLog Security -ErrorAction Stop).MaximumSizeInBytes) -ge 201326592) 'Security log must be at least 192 MiB' 'Increase the Security event log maximum size.'
        if ($Role -eq 'client') {
            $camera = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Camera' -Name AllowCamera -ErrorAction Ignore
            $usb = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices' -Name Deny_All -ErrorAction Ignore
            $refresh = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name GroupPolicyRefreshTime -ErrorAction Ignore
            & $add 'camera-policy-effective' $true ($camera -eq 0) "AllowCamera=$camera" 'Add this workstation to ACL-Deny-Camera-PC and refresh Group Policy.'
            & $add 'usb-storage-policy-effective' $true ($usb -eq 1) "Deny_All=$usb" 'Add this workstation to ACL-Deny-USB-PC and refresh Group Policy.'
            & $add 'background-gpo-refresh-effective' $true ($refresh -eq 30) "GroupPolicyRefreshTime=$refresh" 'Apply WSLAB-v2-GroupPolicy-Refresh.'
        }
        if ($Role -eq 'primary-dc') {
            Import-Module GroupPolicy -ErrorAction Stop
            $wallpaper = Get-GPRegistryValue -Name 'WSLAB-Access-Lock-Wallpaper' -Key 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ValueName Wallpaper -ErrorAction Ignore
            $print = Get-GPRegistryValue -Name 'WSLAB-v2-Print-Policy' -Key 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -ValueName ServerList -ErrorAction Ignore
            $filePolicy = Get-GPRegistryValue -Name 'WSLAB-v2-FileShare-Policy' -Key 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -ValueName RequireSecuritySignature -ErrorAction Ignore
            & $add 'wallpaper-gpo-readback' $true ([bool]$wallpaper.Value -and $wallpaper.Value -like '\\HEIMDALL-FS01.*\Branding\asgard-wallpaper.bmp') ([string]$wallpaper.Value) 'Reconcile the wallpaper GPO and approved branding path.'
            & $add 'trusted-print-server-policy' $true ($print.Value -like 'HEIMDALL-FS01.*') ([string]$print.Value) 'Reconcile the trusted Point-and-Print server policy.'
            & $add 'file-sharing-policy' $true ($filePolicy.Value -eq 1) "RequireSecuritySignature=$($filePolicy.Value)" 'Reconcile the SMB signing file-sharing policy.'
        }
        if ($Role -notin @('client', 'aiml-client')) {
            $caption = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
            if ($caption -match '2025') {
                $getOsConfig = Get-Command Get-OSConfigDesiredConfiguration -ErrorAction Ignore
                if ($getOsConfig) {
                    $osConfigRole = if ($Role -in @('primary-dc', 'secondary-dc')) { 'DomainController' } else { 'MemberServer' }
                    $scenario = "SecurityBaseline/WindowsServer/2025/$osConfigRole"
                    $baseline = @(Get-OSConfigDesiredConfiguration -Scenario $scenario -ErrorAction Stop)
                    $noncompliant = @($baseline | Where-Object { $_.Compliance.Status -ne 'Compliant' })
                    & $add 'server-2025-osconfig-baseline' $true ($baseline.Count -gt 0 -and $noncompliant.Count -eq 0) "$($noncompliant.Count) noncompliant settings" 'Reapply the role-aware OSConfig baseline and resolve drift.'
                    $appControl = @(Get-OSConfigDesiredConfiguration -Scenario 'AppControl\WS2025\DefaultPolicy\Audit' -ErrorAction Stop)
                    & $add 'app-control-audit' $true ($appControl.Count -gt 0 -and @($appControl | Where-Object { $_.Compliance.Status -ne 'Compliant' }).Count -eq 0) 'App Control default policy audit scenario' 'Apply App Control for Business in audit mode and resolve drift.'
                }
                else {
                    & $add 'server-2025-osconfig-baseline' $true $false 'Microsoft.OSConfig is unavailable' 'Install Microsoft.OSConfig and apply the role-aware baseline.'
                }
            }
            elseif ($caption -match '2022') {
                $sctMarker = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WindowsServerLab\Baseline' -Name Server2022SctSha256 -ErrorAction Ignore
                & $add 'server-2022-sct-baseline' $true ([bool]($sctMarker -match '^[A-F0-9]{64}$')) 'Verified SCT import marker' 'Apply the checksum-pinned Server 2022 SCT role baseline.'
            }
        }
    }

    if ($Phase -eq 'full') {
        $windowsApplicationId = '55c92734-d682-4d71-983e-d6ec3f16059f'
        $licensedWindows = @(Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='$windowsApplicationId'" -ErrorAction Stop |
            Where-Object { $_.Name -like 'Windows*' -and $_.PartialProductKey -and $_.LicenseStatus -eq 1 })
        & $add 'windows-activation' $true ($licensedWindows.Count -gt 0) 'Windows Software Licensing LicenseStatus' 'Run Invoke-LabWindowsActivation.ps1 for the selected profile and resolve any edition or activation errors.'
        if ($Role -in @('client', 'aiml-client')) {
            $clientCaption = [string](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption
            & $add 'windows-client-edition' $true ($clientCaption -eq 'Microsoft Windows 11 Education') $clientCaption 'Rebuild the Windows client template from media containing the Windows 11 Education image.'
        }
    }

    $results
}

Export-ModuleMember -Function ConvertTo-LabDistinguishedName, Get-LabProfileVirtualMachine, Import-LabDefinition, Initialize-LabDirectory, Install-LabRole, Set-LabDhcpService, Set-LabSecurityBaseline, Test-LabConfiguration, Test-LabGuestCompliance, Write-LabLog
