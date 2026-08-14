# Backup and recovery

## Destruction gate

The single Terraform state owns the inventory VMs and, when configured, a dedicated lab bridge. Preview and destroy from the workstation:

```bash
terraform -chdir=terraform plan -destroy
terraform -chdir=terraform destroy
```

`terraform_data.backup_before_destroy` invokes the remote backup operation before any dependent VM is destroyed. It verifies every ID/name/ownership tag and creates a `vzdump` snapshot on the configured backup storage with configured retention. Missing resources, identity mismatches, storage failures, or backup failures stop destruction. Inventory changes replace the gate so destructive replacements do not bypass backup.

The guest agent remains enabled and `stop_on_destroy = false`, so Proxmox requests graceful guest shutdown before purging each managed VM and disk. Packer-created templates, certification evidence, and a shared management bridge remain. A Terraform-owned dedicated bridge is removed after its dependent VMs.

## Additional Windows backups

A VM backup is not the complete Active Directory recovery method. Run and test Windows System State backups for both domain controllers. Use `Start-LabSystemStateBackup.ps1` and retain credentials and keys outside this repository.

The file server data disk needs application-consistent file backup and periodic restore tests. Use `Start-LabFileBackup.ps1` and `Test-LabFileRestore.ps1` with an approved target. Record restore evidence independently from Terraform state.

## Recovery order

1. Restore the single Terraform state and verify the shared or dedicated VLAN-aware bridge.
2. Verify or rebuild/certify templates before restoring clones.
3. Restore the forest with Microsoft's AD forest recovery procedure and a tested System State copy.
4. Restore the secondary DC only after the primary recovery state is sound.
5. Restore member servers, file data, and clients.
6. Run `terraform apply`, acceptance, and a zero-change plan.

Keep Terraform state backups, Proxmox VM backups, Windows backups, recovery passwords, and activation material in separately protected systems.
