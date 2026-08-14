# Template and live certification

## Template gate

Foundation derives a replacement digest from Packer configuration, Windows answer/bootstrap files, the build-artifact manifest, Windows media digests, and the VirtIO digest. Mutable lab inventory, policies, and guest-role scripts are delivered during Terraform guest convergence and do not force a golden-image rebuild. Certification evidence is current only when the template ID/name/tags, normalized Proxmox configuration digest, Proxmox version, image-automation digest, and two sequential canaries all match.

An absent template is built. A current certified template is a no-op. A stale template makes ordinary apply fail, and an unowned object at a template ID is never replaced. The rebuild wrapper requires `rebuild-<os>-<id>` and verifies the expected name, template flag, and `wslab-build` tag before removal.

## Proxmox 9.2 acceptance

1. Configure the `nic0` switch/router port with the management network untagged/native and VLANs 90/100 tagged. Verify VLAN-aware `vmbr0` retains management connectivity.
2. Validate `site.json`, then plan the single `terraform` root from the operator workstation.
3. Use the confirmed rebuild command only if automation/media changes made a template stale.
4. Apply `terraform`; guest convergence must complete as part of that apply.
5. Confirm every inventory QEMU agent, address, VLAN tag, Secure Boot, TPM 2.0, CPU/RAM, OS disk, and declared data disk.
6. Run optional activation and full AD/DNS/DHCP/service/security acceptance.
7. Re-run the Terraform plan and require no changes.
8. Exercise `terraform destroy`; prove a failed backup blocks it and a successful destruction leaves shared `vmbr0`, templates 9000/9011, and certification evidence intact.

Retain Terraform plan output, Proxmox task logs, template build receipts, certification JSON, guest acceptance JSON/JUnit, backup reports, and restore-test evidence. Record the exact Proxmox and provider versions with the evidence.
