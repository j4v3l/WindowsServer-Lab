# Compatibility

| Component | Supported target | Policy |
|---|---|---|
| Proxmox VE | 9.2 or later in the 9.x line | Preflight rejects older major/minor versions |
| Terraform | `>= 1.15, < 1.16` | The operator root and both internal modules enforce the constraint |
| Proxmox provider | `bpg/proxmox` `0.111.1` | Exact pin and multi-platform lock files |
| External provider | `hashicorp/external` `2.4.0` | Exact pin and multi-platform lock files |
| Packer | 1.16.0 | Artifact manifest and CI validation |
| Windows Server | 2025 Desktop Experience | Five server roles share template 9000 |
| Windows client | Windows 11 Education | One client uses template 9011 |
| PowerShell | Windows PowerShell 5.1 in guests; PowerShell 7 in CI | Parser and Pester coverage |

The supported inventory is always six machines: 11 vCPU, 17,408 MB maximum RAM, and 456 GB thin-provisioned storage. Proxmox VE 8, Server 2022, alternative lab inventories, and selectable machine-size profiles are outside this version's supported path.

Live certification is tied to the exact Proxmox version, template configuration digest, automation digest, media digest, and two sequential canaries. A provider or automation upgrade requires deliberate recertification.
