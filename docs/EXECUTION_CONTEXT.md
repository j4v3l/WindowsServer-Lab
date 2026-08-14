# Execution context

The operator runs the single `terraform` root from a workstation. The Proxmox provider uses verified HTTPS, while Terraform-internal helpers use strict host-key-checked root SSH to run Packer, bridge/capacity inspection, template certification, backup, and QEMU Guest Agent operations on the selected node.

Windows configuration scripts run inside each guest. Terraform automatically stages the schema-validated inventory, module, and approved scripts through QEMU Guest Agent. Domain, DSRM, and initial-user passwords come from ignored `LabConfig/secrets.json`; only its path enters Terraform configuration. The temporary remote copy is mode 0600 and is deleted when the remote operation ends. Activation keys remain an explicit interactive flow and never enter Terraform.

Provider authentication is environment-only. Prefer `PROXMOX_VE_API_TOKEN`; username/password authentication may use `PROXMOX_VE_USERNAME` and `PROXMOX_VE_PASSWORD`. Do not add API credentials or private-key content to JSON, HCL, variable files, plans, or state. TLS verification and SSH host-key verification are enabled. A private Proxmox CA must be installed in the workstation operating system's trust store; an environment-only CA override is not assumed to work in every provider runtime.

## State and a remote backend

The default local state belongs to the workstation operator. Use `umask 077`, protect state backups, and never commit state or plan files. When multiple operators manage the lab, use one encrypted backend with locking for the single root. Add an empty backend declaration and keep backend credentials in its supported environment/workload identity. For example:

```hcl
terraform {
  backend "s3" {}
}
```

Then migrate the one state deliberately:

```bash
umask 077
terraform -chdir=terraform init -migrate-state \
  -backend-config=/protected/path/windows-server-lab.hcl
```

Confirm the destination is empty before migration, inspect `terraform state list`, and retain a protected backend snapshot. `terraform plan` performs provider/API and remote read-only inspection. `terraform apply` owns all lab creation and convergence. `terraform destroy` invokes the backup gate before VMs; Packer-created templates and the externally managed shared bridge are retained.
