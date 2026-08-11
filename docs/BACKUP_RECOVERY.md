# Backup and recovery runbook

## Backup layers

1. Run `Start-LabSystemStateBackup.ps1` on both domain controllers to a protected non-system volume.
2. Run `Start-LabFileBackup.ps1` on the file server to a protected target.
3. Run `Backup-Lab.sh --apply` on Proxmox for owned VM snapshots to the configured Proxmox/PBS storage. It applies the declared last/daily/weekly/monthly prune policy and records JSON evidence.
4. Verify job results and retention at the destination; a successful command without restorable media is not a passed control.

## File restore drill

Restore a representative file to an alternate path, verify its digest and ACL, record start/end time and backup identifier, then remove the drill copy. Never overwrite the source for a routine test.

## AD System State drill

Clone the DC backup into an isolated network with no route to the active domain. Follow Microsoft's nonauthoritative/authoritative recovery procedure appropriate to the scenario, verify `dcdiag`, DNS, SYSVOL, and replication only within the isolated clone, and destroy the clone after evidence is retained.

## Teardown

Review `Remove-Lab.sh` without `--apply`. The apply path backs up first by default, requires `--confirm <demo>-<profile>`, checks each VM's canonical name and ownership tag, and does not touch unrelated VMs. Use `--skip-backup` only when an existing verified recovery point is recorded.
