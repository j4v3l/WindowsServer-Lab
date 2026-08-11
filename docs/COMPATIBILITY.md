# Compatibility and sizing

## Supported targets

| Component | Primary | Compatibility target | Claim policy |
|---|---|---|---|
| Proxmox VE | 9.2 | 8.4 | Version label only after its core live gate passes |
| Windows Server | 2025 Desktop Experience | 2022 Desktop Experience | Server 2019 is not a v2 target |
| Windows client | Current Windows 11 Enterprise | — | Media/build-specific image index must be verified |
| Guest PowerShell | Windows PowerShell 5.1 | PowerShell 7 for tooling tests | Guest scripts parse under 5.1 |

The Packer unattended image index is media-specific. Confirm the selected edition with `dism /Get-WimInfo` before applying a template build. Operator-supplied licensing, ISO media, VirtIO drivers, network trunks, storage, and backup targets remain prerequisites. The default routed topology also requires a site-controlled DHCP relay from the client VLAN to the primary DC's production address before lease validation can pass.

## Declared profile allocations

| Demo/profile | VMs | vCPU | RAM MB | Disk GB |
|---|---:|---:|---:|---:|
| Asgard smoke | 6 | 11 | 17,408 | 456 |
| Asgard core | 7 | 24 | 49,152 | 1,260 |
| Asgard full | 30 | 70 | 143,360 | 3,100 |
| Olympus smoke | 6 | 11 | 17,408 | 456 |
| Olympus core | 7 | 24 | 53,248 | 1,760 |
| Olympus full | 30 | 80 | 167,936 | 4,000 |

Full profiles should be certified one demo at a time unless `site.json` records sufficient proven capacity. Actual deployment duration is recorded during live certification; this repository does not substitute estimates for measurements.
