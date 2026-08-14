# Security model

Terraform configuration and state contain infrastructure metadata and secret-file paths only. Domain administrator, DSRM, and initial-user passwords live in an ignored mode-0600 JSON file; Terraform's remote runner copies it to an isolated mode-0600 runtime directory, sends values only through QEMU Guest Agent standard input, and removes the runtime directory on exit. Activation remains interactive. Packer creates a temporary PVE token and random Windows build password, then removes both on exit.

The provider uses verified HTTPS (`insecure = false`). Remote helpers require strict SSH host-key verification and an explicit private-key path. Supply API authentication with `PROXMOX_VE_API_TOKEN`, or username/password environment variables when explicitly required. Do not commit `.tfvars`, plans, state, local site/secret files, credentials, private keys, or product keys.

The shared management bridge remains outside Terraform ownership. Preflight requires `vmbr0` to retain its management address/default route, carrier on `nic0`, the correct bridge master, VLAN awareness, and explicit VLAN 90/100 membership. It also rejects stale templates, insufficient capacity, and conflicting IDs/names/IPs.

Every VM uses q35, OVMF, a 4 MB EFI disk with enrolled keys, TPM 2.0, VirtIO SCSI, the guest agent, the Proxmox firewall flag, a single tagged NIC, and sorted ownership tags. Server 2025 uses Microsoft's role-aware OSConfig, Defender, Secured-core, LAPS for member servers, and App Control audit scenarios. Domain policy mappings are written and read back with Group Policy cmdlets.

Execution policy and AppLocker are not treated as security boundaries. App Control enforcement requires reviewed audit evidence. Acceptance is pass/fail with evidence and remediation; percentage scores are not readiness proof.

Destruction validates ownership and requires a successful backup. The provider requests graceful guest shutdown before purging Terraform-managed VM disks. Packer templates and externally managed shared networking remain outside provider-managed destruction.
