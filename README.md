# Windows Server Lab on Proxmox

This repository builds a Terraform-managed Asgard lab on Proxmox VE 9.2. The canonical inventory contains five Windows Server 2025 machines and one Windows 11 Education client; extra `member-server` and `client` entries scale through the same inventory. One Terraform root validates or creates the lab bridge, asks Packer to build and certify missing Windows templates, creates every VM, and converges Active Directory and guest roles over QEMU Guest Agent. There is no separate deploy or guest-configuration command.

## Topology

| VM ID | Name | Role | vCPU / RAM | Storage | Network |
|---:|---|---|---|---|---|
| 5100 | ODIN-DC01 | Primary DC | 2 / 3072 MB | 64 GB | `192.168.90.10`, VLAN 90 |
| 5101 | FRIGG-DC02 | Secondary DC | 2 / 3072 MB | 64 GB | `192.168.90.11`, VLAN 90 |
| 5102 | HEIMDALL-FS01 | File server | 2 / 2560 MB | 64 GB + 56 GB | `192.168.90.20`, VLAN 90 |
| 5103 | BALDER-WEB01 | Web server | 1 / 2048 MB | 64 GB | `192.168.90.30`, VLAN 90 |
| 5104 | VIDAR-SEC01 | Management/security | 2 / 2560 MB | 64 GB | `192.168.90.40`, VLAN 90 |
| 5110 | ODIN-WS01 | Windows 11 client | 2 / 4096 MB | 80 GB | `192.168.100.10`, VLAN 100 |

Servers use `192.168.90.1`; the client uses `192.168.100.1`. DNS is `192.168.90.10` and `192.168.90.11`. The upstream router owns both gateways and the inter-VLAN policy. Planned capacity is 11 vCPU, 17,408 MB RAM, and 456 GB thin-provisioned storage.

## Quick start

Run Terraform from your workstation. SSH host-key verification must already succeed for the Proxmox host, and the SSH account must be able to run the host-local Packer, certification, backup, and QEMU Guest Agent operations (the default is `root`). The default topology uses existing VLAN-aware management bridge `vmbr0`; Terraform validates it without changing its address or default route. A dedicated non-management bridge can instead be fully Terraform-owned through `site.json`.

```bash
cp LabConfig/site.example.json LabConfig/site.json
cp LabConfig/secrets.example.json LabConfig/secrets.json
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
chmod 600 LabConfig/site.json LabConfig/secrets.json terraform/terraform.tfvars
Tools/Proxmox/Validate-LabConfig.sh --site LabConfig/site.json

export PROXMOX_VE_API_TOKEN='terraform@pve!provider=REDACTED'

terraform -chdir=terraform init
terraform -chdir=terraform plan -out=lab.tfplan
terraform -chdir=terraform apply lab.tfplan
```

Set the Windows media volumes and real SHA-256 values, storage IDs, physical uplink, temporary build addresses, and backup storage in `site.json`. Set strong domain-administrator, DSRM, and initial-user passwords in ignored `secrets.json`; Terraform stores only that file's path, and the remote runner deletes its temporary copy after guest convergence. Use `PROXMOX_VE_USERNAME` and `PROXMOX_VE_PASSWORD` instead of the token only when the site intentionally uses password authentication. TLS verification is always enabled. If the Proxmox API uses a private CA, install that CA in the workstation operating system's trust store before `plan`; relying only on `SSL_CERT_FILE` is not portable across provider runtimes.

Template builds automatically inject Microsoft-published KMS client setup keys for Windows Server 2025 Standard and Windows 11 Education so Setup remains unattended. These public keys select the installation edition but do not activate Windows or grant a license; activation remains separate.

An absent template is built and certified by foundation. A stale template makes ordinary apply fail. Rebuild only with the exact confirmation printed by the tool:

```bash
Tools/Terraform/Rebuild-Templates.sh \
  --site LabConfig/site.json \
  --os server-2025 \
  --confirm rebuild-server-2025-9000
```

Guest configuration is part of `terraform apply`. Windows activation remains deliberately separate because product keys are licensing secrets, not lab-creation inputs. If desired, use a checkout on the Proxmox node for the interactive activation and acceptance commands:

```bash
sudo Tools/Proxmox/Activate-LabGuests.sh --site LabConfig/site.json --action activate --apply
sudo Tools/Proxmox/Test-Lab.sh --site LabConfig/site.json --phase full
```

Require a zero-change plan after acceptance:

```bash
terraform -chdir=terraform plan -detailed-exitcode
```

Destroy first backs up every inventory VM. A failed backup blocks destruction. Shared management networking and Packer-created templates are retained; a Terraform-owned dedicated lab bridge is removed after the VMs:

```bash
terraform -chdir=terraform destroy
```

## Repository layout

- `LabConfig/lab.json`: schema-validated source of truth for Terraform and PowerShell
- `LabConfig/site.example.json`: non-secret Proxmox, storage, media, bridge, capacity, and key-path settings
- `terraform`: the only operator entry point and state; composes foundation and lab modules
- `terraform/foundation`: bridge validation/creation plus Packer template orchestration and certification
- `terraform/lab`: inventory-driven full clones, static networking, Secure Boot, TPM, guest agent, disks, guest convergence, startup order, and backup-gated destruction
- `packer/windows`: Server 2025 and Windows 11 template construction
- `Tools/Terraform` and `Tools/Proxmox`: Terraform-invoked remote preflight, Packer reconciliation, backup, guest convergence, activation, and acceptance helpers
- `Scripts`: guest-side Active Directory, service, security, sharing, enrollment, and recovery operations

Local Terraform state is the default and must remain protected with restrictive permissions. State, plans, local variable files, secret files, and `.terraform` directories are ignored. Teams should use an encrypted locking backend when more than one operator manages the lab.

## Runbooks

- [Terraform startup](docs/SMOKE_STARTUP.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Execution context](docs/EXECUTION_CONTEXT.md)
- [Template and live certification](docs/LIVE_CERTIFICATION.md)
- [Backup and recovery](docs/BACKUP_RECOVERY.md)
- [Security model](docs/SECURITY_MODEL.md)
- [Windows activation](docs/WINDOWS_ACTIVATION.md)
- [Machine enrollment](docs/MACHINE_ENROLLMENT.md)
- [Access controls](docs/ACCESS_CONTROL.md)
- [Resource sharing](docs/RESOURCE_SHARING.md)
- [Generated inventory](docs/generated/INVENTORY.md)
