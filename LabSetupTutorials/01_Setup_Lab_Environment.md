# Setting up the Windows lab environment

This lab intentionally has one creation interface: [the Terraform startup runbook](../docs/SMOKE_STARTUP.md). Manual Proxmox VM wizards and legacy finish-setup scripts are not supported.

Terraform reads `LabConfig/lab.json` for identities, resources, roles, disks, addresses, and VLANs. It validates/creates the appropriate bridge, invokes Packer to produce certified Server 2025 and Windows 11 templates, creates full clones, and automatically converges AD DS, DNS, DHCP, domain joins, file/IIS/event services, security baselines, and access policy.

Prepare these ignored local files:

```bash
cp LabConfig/site.example.json LabConfig/site.json
cp LabConfig/secrets.example.json LabConfig/secrets.json
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
chmod 600 LabConfig/site.json LabConfig/secrets.json terraform/terraform.tfvars
```

Then validate, plan, and apply exactly as documented in the runbook. To add capacity later, use [Scaling servers and clients](13_Additional_Servers_Setup.md); do not clone a VM manually.
