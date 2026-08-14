# Destroying and recovering the Terraform lab

Terraform owns every VM in `LabConfig/lab.json`. Packer owns the two reusable Windows templates. A shared management bridge remains external; a dedicated lab bridge is Terraform-owned.

## Before destruction

- Keep `LabConfig/site.json`, `terraform/terraform.tfvars`, and the Terraform state available.
- Confirm the configured backup storage has enough free capacity.
- Complete any Windows System State backup required for domain-controller recovery.

Preview the graph from the operator workstation:

```bash
terraform -chdir=terraform plan -destroy
```

The plan includes all inventory VMs and the backup gate. Packer template IDs `9000` and `9011` are not provider-managed template resources and are not deleted.

## Destroy

```bash
terraform -chdir=terraform destroy
```

Terraform first backs up every owned VM. It then requests graceful shutdown and purges managed VM disks. A failed backup or ownership mismatch blocks removal. Shared `vmbr0` and both templates remain; an optional dedicated lab bridge is removed last.

## Recreate

```bash
terraform -chdir=terraform plan -out=lab.tfplan
terraform -chdir=terraform apply lab.tfplan
```

Fresh full clones and all Windows role configuration are recreated by the same apply. No deployment or guest-configuration script is run manually.

For data restoration and Active Directory recovery order, follow [Backup and Recovery](../docs/BACKUP_RECOVERY.md). Do not apply against existing resources with empty state; restore the state backup or deliberately import the inventory first.
