BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $modulePath = Join-Path $script:repoRoot 'Scripts\WindowsServerLab\WindowsServerLab.psd1'
    Import-Module $modulePath -Force
}

Describe 'WindowsServerLab v2 canonical definitions' {
    It '<demo> has exact, unique, safe smoke, core, and full inventories' -ForEach @(
        @{ demo = 'asgard' },
        @{ demo = 'olympus' }
    ) {
        $definition = Import-LabDefinition -Path (Join-Path $script:repoRoot "LabConfig\demos\$demo.json")
        $smoke = @(Get-LabProfileVirtualMachine -Definition $definition -Profile smoke)
        $smoke.Count | Should -Be 6
        @($smoke | Where-Object role -in @('client', 'aiml-client')).Count | Should -Be 1
        @($smoke | Where-Object role -notin @('client', 'aiml-client')).Count | Should -Be 5
        ($smoke.cores | Measure-Object -Sum).Sum | Should -Be 11
        ($smoke.memoryMB | Measure-Object -Sum).Sum | Should -Be 17408
        (($smoke.diskGB | Measure-Object -Sum).Sum + ($smoke.dataDisks.sizeGB | Measure-Object -Sum).Sum) | Should -Be 456
        @(Get-LabProfileVirtualMachine -Definition $definition -Profile core).Count | Should -Be 7
        @(Get-LabProfileVirtualMachine -Definition $definition -Profile full).Count | Should -Be 30
        $results = @(Test-LabConfiguration -Definition $definition -Profile full)
        @($results | Where-Object { -not $_.Passed }).Count | Should -Be 0
        $definition.domain.dnsName | Should -Not -Match '\.local$'
        $definition.domain.legacyDnsName | Should -Match '\.local$'
        @(Test-LabConfiguration -Definition $definition -Profile smoke | Where-Object { -not $_.Passed }).Count | Should -Be 0
    }
}

Describe 'WindowsServerLab helpers' {
    It 'converts DNS names to distinguished names' {
        ConvertTo-LabDistinguishedName -DomainName 'ad.asgard.test' | Should -Be 'DC=ad,DC=asgard,DC=test'
    }

    It 'orders role deployment by boot order and VM ID' {
        $definition = Import-LabDefinition -Path (Join-Path $script:repoRoot 'LabConfig\demos\asgard.json')
        $selected = @(Get-LabProfileVirtualMachine -Definition $definition -Profile core)
        $selected[0].role | Should -Be 'primary-dc'
        $selected[1].role | Should -Be 'secondary-dc'
        $selected[-1].role | Should -Be 'client'
    }

    It 'resolves smoke profile resource overrides without changing core sizing' {
        $definition = Import-LabDefinition -Path (Join-Path $script:repoRoot 'LabConfig\demos\asgard.json')
        $smokeDc = Get-LabProfileVirtualMachine -Definition $definition -Profile smoke | Where-Object role -eq 'primary-dc'
        $coreDc = Get-LabProfileVirtualMachine -Definition $definition -Profile core | Where-Object role -eq 'primary-dc'
        $smokeDc.cores | Should -Be 2
        $smokeDc.memoryMB | Should -Be 3072
        $smokeDc.balloonMinimumMB | Should -Be 2560
        $coreDc.cores | Should -Be 4
        $coreDc.memoryMB | Should -Be 8192
        $smokeFile = Get-LabProfileVirtualMachine -Definition $definition -Profile smoke | Where-Object role -eq 'file-server'
        $smokeFile.diskGB | Should -Be 64
        $smokeFile.dataDisks.Count | Should -Be 1
        $smokeFile.dataDisks[0].sizeGB | Should -Be 56
        $smokeFile.dataDisks[0].driveLetter | Should -Be 'D'
    }

    It 'redacts secret-like values from structured logs' {
        $log = Join-Path $TestDrive 'log.jsonl'
        $keyShapedValue = (@('ABCDE') * 5) -join '-'
        Write-LabLog -Level Info -Message "token=do-not-retain password:also-hidden $keyShapedValue" -LogPath $log -Data @{ Credential = 'hidden-data'; ProductKey = 'hidden-key-data'; Note = 'secret=hidden-note' }
        $content = Get-Content -LiteralPath $log -Raw
        $content | Should -Not -Match "do-not-retain|also-hidden|hidden-data|hidden-note|hidden-key-data|$([regex]::Escape($keyShapedValue))"
        $content | Should -Match '\[REDACTED\]'
        $content | Should -Match '\[REDACTED-PRODUCT-KEY\]'
    }

    It 'rejects unsupported schema versions' {
        $fixture = Join-Path $TestDrive 'invalid.json'
        '{"schemaVersion":1,"demo":"asgard","domain":{"dnsName":"ad.asgard.test"},"virtualMachines":[]}' | Set-Content -LiteralPath $fixture
        { Import-LabDefinition -Path $fixture } | Should -Throw
    }
}

Describe 'Security implementation integrity' {
    It 'defines unique, scope-correct group-filtered access controls' {
        $catalog = Get-Content -LiteralPath (Join-Path $script:repoRoot 'LabConfig\policies\access-controls.json') -Raw | ConvertFrom-Json
        @($catalog.controls).Count | Should -BeGreaterOrEqual 10
        @($catalog.controls.id | Sort-Object -Unique).Count | Should -Be @($catalog.controls).Count
        @($catalog.controls.groupName | Sort-Object -Unique).Count | Should -Be @($catalog.controls).Count
        @($catalog.controls.gpoName | Sort-Object -Unique).Count | Should -Be @($catalog.controls).Count
        @($catalog.controls | Where-Object groupName | Where-Object { $_.groupName.Length -gt 20 }).Count | Should -Be 0
        @($catalog.controls.id) | Should -Contain 'Camera'
        @($catalog.controls.id) | Should -Contain 'Microphone'
        @($catalog.controls.id) | Should -Contain 'USBStorage'
        @($catalog.controls.id) | Should -Contain 'Wallpaper'
        foreach ($control in $catalog.controls) {
            $prefix = if ($control.scope -eq 'Computer') { 'HKLM\' } else { 'HKCU\' }
            @($control.settings | Where-Object { -not $_.key.StartsWith($prefix) }).Count | Should -Be 0
        }
    }

    It 'implements access changes with real GPO read-back and AD membership' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabAccessControl.ps1') -Raw
        $content | Should -Match 'Set-GPRegistryValue'
        $content | Should -Match 'Get-GPRegistryValue'
        $content | Should -Match 'Set-GPPermission'
        $content | Should -Match 'Add-ADGroupMember'
        $content | Should -Match 'Remove-ADGroupMember'
        $content | Should -Not -Match 'Set-ExecutionPolicy|AppLocker'
    }

    It 'configures native background Group Policy refresh with read-back evidence' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabGroupPolicyRefresh.ps1') -Raw
        $content | Should -Match 'GroupPolicyRefreshTime'
        $content | Should -Match 'GroupPolicyRefreshTimeOffset'
        $content | Should -Match 'DisableBkGndGroupPolicy'
        $content | Should -Match 'SyncForegroundPolicy'
        $content | Should -Match "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System"
        $content | Should -Match "HKCU\\SOFTWARE\\Policies\\Microsoft\\Windows\\System"
        $content | Should -Match "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon"
        $content | Should -Match 'Get-GPRegistryValue'
        $content | Should -Match 'Get-GPInheritance'
        $content | Should -Not -Match 'Register-ScheduledTask|schtasks\.exe'
        $testContent = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Test-LabGroupPolicyRefresh.ps1') -Raw
        $testContent | Should -Match 'Get-Service gpsvc'
        $testContent | Should -Match 'gpresult\.exe'
        $testContent | Should -Match 'HKEY_LOCAL_MACHINE'
        $testContent | Should -Match 'HKEY_CURRENT_USER'
    }

    It 'supports hypervisor-independent machine enrollment without plaintext credentials' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabMachineEnrollment.ps1') -Raw
        $content | Should -Match "ValidateSet\('Enroll', 'Disenroll', 'Status'\)"
        $content | Should -Match 'Add-Computer'
        $content | Should -Match 'Remove-Computer'
        $content | Should -Match 'ConfirmLocalAdministratorAccess'
        $content | Should -Match 'ConfirmDirectoryObjectDeletion'
        $content | Should -Match 'Management\.Automation\.PSCredential'
        $content | Should -Not -Match 'ConvertTo-SecureString.+AsPlainText|\bqm\b|Get-VM|Import-Module Hyper-V'
    }

    It 'keeps Windows activation material runtime-only and verifies licensing' {
        $local = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabWindowsActivation.ps1') -Raw
        $fleet = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Invoke-LabWindowsActivation.ps1') -Raw
        $packer = Get-Content -LiteralPath (Join-Path $script:repoRoot 'packer\windows\windows.pkr.hcl') -Raw
        $local | Should -Match 'Security\.SecureString'
        $local | Should -Match 'InstallProductKey'
        $local | Should -Match 'ClearProductKeyFromRegistry'
        $local | Should -Match 'LicenseStatus'
        $local | Should -Not -Match 'slmgr|ConvertTo-SecureString.+AsPlainText'
        $fleet | Should -Match "ValidateSet\('Servers', 'All'\)"
        $fleet | Should -Match 'Invoke-Command'
        $fleet | Should -Match "Authentication = 'Kerberos'"
        $fleet | Should -Match 'Security\.SecureString'
        $fleet | Should -Match 'Get-Secret'
        $packer | Should -Match 'Windows 11 Education'
        $packer | Should -Not -Match '(?i)product.?key'
        $module = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\WindowsServerLab\WindowsServerLab.psm1') -Raw
        $module | Should -Match "'windows-activation'"
        $module | Should -Match "'windows-client-edition'"
    }

    It 'limits activation remoting to domain Kerberos and the local subnet' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Enable-LabPowerShellRemoting.ps1') -Raw
        $content | Should -Match 'PartOfDomain'
        $content | Should -Match 'AllowUnencrypted.+false'
        $content | Should -Match 'Auth\\Basic.+false'
        $content | Should -Match 'Auth\\Negotiate.+false'
        $content | Should -Match 'Auth\\Kerberos.+true'
        $content | Should -Match 'Profile Domain'
        $content | Should -Match 'RemoteAddress LocalSubnet'
    }

    It 'retains client onboarding only as a v2 compatibility shim' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Client\Client-Onboarding.ps1') -Raw
        $content | Should -Match 'deprecated'
        $content | Should -Match 'Set-LabMachineEnrollment.ps1'
        $content | Should -Not -Match 'Add-Computer|Rename-Computer'
    }

    It 'publishes printers with trusted-server policy and verified ACLs' {
        $policy = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabPrintPolicy.ps1') -Raw
        $server = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabSharedPrinter.ps1') -Raw
        $client = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabPrinterConnection.ps1') -Raw
        $policy | Should -Match 'PackagePointAndPrintOnly'
        $policy | Should -Match 'PackagePointAndPrintServerList'
        $policy | Should -Match 'RestrictDriverInstallationToAdministrators'
        $policy | Should -Match 'NoWarningNoElevationOnInstall.+Value = 0'
        $server | Should -Match 'DriverInfSha256'
        $server | Should -Match 'IsPackageAware'
        $server | Should -Match 'Published \$true|Published'
        $server | Should -Match 'PermissionSDDL'
        $server | Should -Match '0x20008'
        $client | Should -Match 'Add-Printer -ConnectionName'
        $client | Should -Match 'Remove-Printer'
    }

    It 'enforces file-share policy at GPO, SMB, NTFS, and AD membership layers' {
        $policy = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabFileSharePolicy.ps1') -Raw
        $server = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabSharedFolder.ps1') -Raw
        $policy | Should -Match 'RequireSecuritySignature'
        $policy | Should -Match 'AllowInsecureGuestAuth'
        $policy | Should -Match "ValidateSet\('Read', 'Change', 'Deny', 'Remove'\)"
        $policy | Should -Match 'Add-ADGroupMember'
        $policy | Should -Match 'Remove-ADGroupMember'
        $server | Should -Match 'EncryptData \$true'
        $server | Should -Match 'FolderEnumerationMode AccessBased'
        $server | Should -Match 'Block-SmbShareAccess'
        $server | Should -Match 'FileSystemAccessRule'
        $server | Should -Match 'AdoptExistingPath'
    }

    It 'uses real registry paths in the v2 domain policy' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabDomainPolicy.ps1') -Raw
        $content | Should -Match 'HKLM\\SOFTWARE\\Policies'
        $content | Should -Match 'Get-GPRegistryValue'
        $content | Should -Not -Match 'Administrative Templates\\'
    }

    It 'does not use percentage scores to assert production readiness' {
        $paths = @(
            (Join-Path $script:repoRoot 'Scripts\Test-LabCompliance.ps1'),
            (Join-Path $script:repoRoot 'Demo\SECURITY_VALIDATION_SCRIPT.ps1')
        )
        (Get-Content -LiteralPath $paths -Raw) | Should -Not -Match 'ProductionReady|ScorePercentage'
    }

    It 'retains demo deployment names only as deprecation shims' {
        foreach ($path in @('Demo\Asgard\Scripts\Deploy-AsgardLab.ps1', 'Demo\Olympus\Scripts\Deploy-OlympusLab.ps1')) {
            $content = Get-Content -LiteralPath (Join-Path $script:repoRoot $path) -Raw
            $content | Should -Match 'deprecated'
            $content | Should -Match 'Tools/Proxmox/Deploy-Lab.sh'
            $content | Should -Not -Match '\bqm\s+create\b'
        }
    }
}
