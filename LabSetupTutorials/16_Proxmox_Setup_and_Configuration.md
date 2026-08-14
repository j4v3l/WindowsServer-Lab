# Proxmox host prerequisites

Proxmox VE installation and its management network exist before this repository is applied. Lab VMs and reusable Windows templates must not be created manually.

## Required host state

- Proxmox VE 9.2 or later with API and SSH reachable from the operator workstation
- Trusted API certificate (or its CA installed on the workstation) and verified SSH host key
- API identity with the permissions required by the declared bridge and VM resources
- Root SSH key access for Packer media preparation, template certification, backup, and QEMU Guest Agent execution
- VM, ISO, snippet, and backup storage IDs matching `LabConfig/site.json`
- Server 2025, Windows 11 Education, and VirtIO ISO volumes with approved SHA-256 values
- `packer`, Terraform host prerequisites, `xorriso`, `genisoimage`, `jq`, and the other tools checked by remote preflight

## Network ownership

In shared mode, existing `vmbr0` remains the addressed Proxmox management bridge. Its physical switch port carries the management network untagged/native and VLANs 90 and 100 tagged. Terraform validates this safety boundary and does not rewrite the management address or route.

In dedicated mode, select an unused physical uplink and non-`vmbr0` bridge in `site.json`. Terraform creates the unnumbered VLAN-aware bridge and removes it only after dependent lab VMs are destroyed.

Continue with [Terraform startup and acceptance](../docs/SMOKE_STARTUP.md).
