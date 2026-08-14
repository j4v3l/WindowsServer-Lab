BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $modulePath = Join-Path $script:repoRoot 'Scripts\WindowsServerLab\WindowsServerLab.psd1'
    Import-Module $modulePath -Force
    $script:definition = Import-LabDefinition -Path (Join-Path $script:repoRoot 'LabConfig\lab.json')
}

Describe 'WindowsServerLab v3 canonical inventory' {
    It 'contains exactly five Server 2025 VMs and one Windows 11 client' {
        $machines = @(Get-LabVirtualMachine -Definition $script:definition)
        $machines.Count | Should -Be 6
        @($machines | Where-Object os -eq 'server-2025').Count | Should -Be 5
        @($machines | Where-Object os -eq 'windows-11').Count | Should -Be 1
        @($machines | Where-Object role -eq 'client').Count | Should -Be 1
    }

    It 'has exact capacity and unique identities' {
        $machines = @(Get-LabVirtualMachine -Definition $script:definition)
        ($machines.cores | Measure-Object -Sum).Sum | Should -Be 11
        ($machines.memoryMB | Measure-Object -Sum).Sum | Should -Be 17408
        (($machines.diskGB | Measure-Object -Sum).Sum + ($machines.dataDisks.sizeGB | Measure-Object -Sum).Sum) | Should -Be 456
        @($machines.id | Sort-Object -Unique).Count | Should -Be 6
        @($machines.name | Sort-Object -Unique).Count | Should -Be 6
        @($machines.nics.ipAddress | Sort-Object -Unique).Count | Should -Be 6
    }

    It 'uses the exact server and client VLANs, subnets, gateways, and DNS' {
        $script:definition.networks.windowsServers.vlanId | Should -Be 90
        $script:definition.networks.windowsServers.cidr | Should -Be '192.168.90.0/24'
        $script:definition.networks.windowsServers.gateway | Should -Be '192.168.90.1'
        $script:definition.networks.windowsClients.vlanId | Should -Be 100
        $script:definition.networks.windowsClients.cidr | Should -Be '192.168.100.0/24'
        $script:definition.networks.windowsClients.gateway | Should -Be '192.168.100.1'
        @($script:definition.networks.windowsServers.dnsServers) | Should -Be @('192.168.90.10', '192.168.90.11')
        @($script:definition.networks.windowsClients.dnsServers) | Should -Be @('192.168.90.10', '192.168.90.11')

        $servers = @($script:definition.virtualMachines | Where-Object os -eq 'server-2025')
        @($servers | Where-Object { $_.nics.Count -ne 1 -or $_.nics[0].network -ne 'windowsServers' }).Count | Should -Be 0
        $client = @($script:definition.virtualMachines | Where-Object os -eq 'windows-11')
        $client[0].nics[0].network | Should -Be 'windowsClients'
    }

    It 'passes every module configuration check' {
        $results = @(Test-LabConfiguration -Definition $script:definition)
        @($results | Where-Object { -not $_.Passed }).Count | Should -Be 0
    }

    It 'accepts an additional inventory-driven member server without changing deployment code' {
        $scaled = $script:definition | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $member = $scaled.virtualMachines | Where-Object role -eq 'web-server' | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $member.id = 5120
        $member.name = 'TYR-APP01'
        $member.role = 'member-server'
        $member.bootOrder = 45
        $member.nics[0].ipAddress = '192.168.90.50'
        $scaled.virtualMachines = @($scaled.virtualMachines) + $member

        $results = @(Test-LabConfiguration -Definition $scaled)
        @($results | Where-Object { -not $_.Passed }).Count | Should -Be 0
        @(Get-LabVirtualMachine -Definition $scaled).Count | Should -Be 7
    }

    It 'orders domain controllers before services and the client' {
        $machines = @(Get-LabVirtualMachine -Definition $script:definition)
        $machines[0].role | Should -Be 'primary-dc'
        $machines[1].role | Should -Be 'secondary-dc'
        $machines[-1].role | Should -Be 'client'
    }

    It 'rejects old and unknown inventory schemas' {
        $fixture = Join-Path $TestDrive 'invalid.json'
        '{"schemaVersion":2,"demo":"asgard","virtualMachines":[]}' | Set-Content -LiteralPath $fixture
        { Import-LabDefinition -Path $fixture } | Should -Throw
    }
}

Describe 'WindowsServerLab helpers and secret handling' {
    It 'converts DNS names to distinguished names' {
        ConvertTo-LabDistinguishedName -DomainName 'ad.asgard.test' | Should -Be 'DC=ad,DC=asgard,DC=test'
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

    It 'keeps secret values outside Terraform while allowing local secret and key paths' {
        $terraform = (Get-ChildItem -LiteralPath (Join-Path $script:repoRoot 'terraform') -Recurse -File -Include *.tf,*.tftest.hcl | Get-Content -Raw) -join "`n"
        $terraform | Should -Not -Match '(?i)domain.?password|windows.?password|product.?key|activation.?key'
        $terraform | Should -Not -Match 'private_key\s*=\s*file\('
        $terraform | Should -Match 'proxmox_ssh_private_key_path'

        $bootstrap = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Invoke-LabBootstrap.ps1') -Raw
        $bootstrap | Should -Match 'Security\.SecureString'
        $bootstrap | Should -Match 'Management\.Automation\.PSCredential'
        $bootstrap | Should -Not -Match 'ConvertTo-SecureString.+AsPlainText'
    }
}

Describe 'Supported operational path' {
    It 'does not expose the removed demo, profile, Olympus, AI-client, or Server 2022 APIs' {
        $paths = @(
            (Join-Path $script:repoRoot 'Scripts\WindowsServerLab'),
            (Join-Path $script:repoRoot 'Scripts\Initialize-LabDomain.ps1'),
            (Join-Path $script:repoRoot 'Scripts\Initialize-LabDataDisks.ps1'),
            (Join-Path $script:repoRoot 'Scripts\Invoke-LabBootstrap.ps1'),
            (Join-Path $script:repoRoot 'Scripts\Invoke-LabWindowsActivation.ps1'),
            (Join-Path $script:repoRoot 'Tools\Proxmox'),
            (Join-Path $script:repoRoot 'Tools\Terraform')
        )
        $content = (Get-ChildItem -LiteralPath $paths -Recurse -File -Include *.ps1,*.psm1,*.psd1,*.sh | Get-Content -Raw) -join "`n"
        $content | Should -Not -Match '(?i)--demo|--profile|LabConfig[\\/]demos|aiml-client|server-2022|olympus'
    }

    It 'has removed the imperative VM and bridge lifecycle scripts' {
        foreach ($path in @('Deploy-Lab.sh', 'Remove-Lab.sh', 'Configure-LabNetwork.sh')) {
            Test-Path -LiteralPath (Join-Path $script:repoRoot "Tools\Proxmox\$path") | Should -BeFalse
        }
    }

    It 'uses real GPO, AD, SMB, and print operations' {
        $access = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabAccessControl.ps1') -Raw
        $files = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabFileSharePolicy.ps1') -Raw
        $print = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabPrintPolicy.ps1') -Raw
        $access | Should -Match 'Set-GPRegistryValue|Get-GPRegistryValue'
        $access | Should -Match 'Add-ADGroupMember|Remove-ADGroupMember'
        $files | Should -Match 'RequireSecuritySignature'
        $files | Should -Match 'Add-ADGroupMember|Remove-ADGroupMember'
        $print | Should -Match 'PackagePointAndPrintServerList'
        $print | Should -Match 'RestrictDriverInstallationToAdministrators'
    }

    It 'supports hypervisor-independent enrollment without plaintext credentials' {
        $content = Get-Content -LiteralPath (Join-Path $script:repoRoot 'Scripts\Set-LabMachineEnrollment.ps1') -Raw
        $content | Should -Match "ValidateSet\('Enroll', 'Disenroll', 'Status'\)"
        $content | Should -Match 'Add-Computer|Remove-Computer'
        $content | Should -Match 'Management\.Automation\.PSCredential'
        $content | Should -Not -Match 'ConvertTo-SecureString.+AsPlainText|\bqm\b|Get-VM|Import-Module Hyper-V'
    }
}
