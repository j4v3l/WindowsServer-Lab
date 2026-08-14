# Scaling servers and clients

Scale the lab by adding entries to `LabConfig/lab.json`. Terraform's `for_each` creates the additional clone, and the same automatic QEMU Guest Agent convergence configures it. No deploy script or Proxmox clone command is added.

The five core roles (`primary-dc`, `secondary-dc`, `file-server`, `web-server`, and `management-server`) must remain singletons. Add general Windows Server capacity with `member-server`; add workstation capacity with `client` plus its `department` and `user` block.

Example member server entry:

```json
{
  "id": 5120,
  "name": "TYR-APP01",
  "role": "member-server",
  "os": "server-2025",
  "bootOrder": 45,
  "cores": 2,
  "memoryMB": 3072,
  "balloonMinimumMB": 2048,
  "diskGB": 64,
  "nics": [
    {
      "network": "windowsServers",
      "ipAddress": "192.168.90.50",
      "prefixLength": 24,
      "defaultGateway": true
    }
  ]
}
```

Choose a unique VM ID, name, address, and boot order. Validate and review capacity before applying:

```bash
Tools/Proxmox/Validate-LabConfig.sh --site LabConfig/site.json
terraform -chdir=terraform plan -out=scale.tfplan
terraform -chdir=terraform apply scale.tfplan
```

Removal is also declarative: delete the inventory entry and review the plan. The backup gate runs before Terraform destroys the removed VM.
