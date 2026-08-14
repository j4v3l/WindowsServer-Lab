# Proxmox lab quick start

The supported lab is created only by the single Terraform root. Do not create, clone, resize, or network lab VMs in the Proxmox UI or with `qm`; those changes bypass state and will cause drift.

## Prerequisites

- Proxmox VE 9.2 or later at the host and node named in `terraform/terraform.tfvars`
- API token exported through `PROXMOX_VE_API_TOKEN`
- Strict host-key-checked root SSH using the configured private-key path
- Storage for at least the capacity calculated from `LabConfig/lab.json`
- Verified Server 2025, Windows 11 Education, and VirtIO ISO volumes
- Existing VLAN-aware shared management trunk for VLANs 90/100, or an unused dedicated uplink Terraform may own
- Upstream gateways `192.168.90.1` and `192.168.100.1`

Follow [Terraform startup and acceptance](../docs/SMOKE_STARTUP.md). The complete creation path is:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan -out=lab.tfplan
terraform -chdir=terraform apply lab.tfplan
```

Terraform invokes Packer for missing templates, creates every inventory VM, and converges Windows roles. Product-key activation is the only optional post-creation secret flow.
