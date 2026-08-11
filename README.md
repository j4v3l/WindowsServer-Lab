# Windows Server Lab v2

Windows Server Lab v2 builds repeatable, production-like Active Directory labs on Proxmox VE. It is a secure lab framework, not a turnkey enterprise production environment.

The repository now has canonical, schema-validated inventories, dry-run-first Proxmox automation, Packer-built Windows templates, phased guest configuration, evidence-based security checks, backup/teardown safeguards, and CI tests. A release is not called Proxmox-version validated until its live certification run has passed.

## Profiles

| Demo | Default domain | Smoke | Core | Full | Distinguishing feature |
|---|---|---:|---:|---:|---|
| Asgard | `ad.asgard.test` | 6 VMs | 7 VMs | 30 VMs | Conventional segmented enterprise lab |
| Olympus | `ad.olympus.test` | 6 VMs | 7 VMs | 30 VMs | Isolated, optional AI/ML feature pack |

The default smoke profile has two domain controllers, a file server, a web server, a management/security server, and one Windows 11 client. It is the six-machine functional test requested for resource-constrained hosts. Core adds a second client; full selects all 25 documented departmental workstations. Existing `.local` labs remain supported with `--legacy-domain`; the tooling does not attempt an AD domain rename.

## Quick start

Run remote inspection/preparation from the operator workstation, provisioning commands on the Proxmox node, and PowerShell commands inside Windows guests. The [six-VM startup runbook](docs/SMOKE_STARTUP.md) separates those contexts explicitly.

1. Copy and edit the site mapping. The tooling never edits the Proxmox management network.

   ```bash
   cp LabConfig/site.example.json LabConfig/site.json
   cp LabConfig/operator.example.json LabConfig/operator.json
   Tools/Proxmox/Validate-LabConfig.sh --demo asgard --profile smoke --site LabConfig/site.json
   Tools/Proxmox/Inspect-RemoteHost.sh --operator LabConfig/operator.json --site LabConfig/site.json --demo asgard --profile smoke
   ```

2. Prepare the host with checksum-pinned Packer and VirtIO artifacts, then build the Server 2025 and Windows 11 templates needed by smoke. Every command is plan-only until `--apply` is added. Server 2022 can be built later for its compatibility gate.

   ```bash
   Tools/Proxmox/Prepare-LabHost.sh --operator LabConfig/operator.json --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json
   Tools/Proxmox/Build-WindowsTemplate.sh --os server-2025 --iso /path/server-2025.iso --iso-sha256 SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json
   Tools/Proxmox/Build-WindowsTemplate.sh --os windows-11 --iso /path/windows-11.iso --iso-sha256 SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json
   ```

   Apply mode resolves Proxmox API credentials and the temporary Windows build password through `PKR_VAR_*` environment variables. Those sensitive values must come from the operator's runtime secret system, never JSON or command arguments. The non-secret Cloudbase-Init URL and digest come from the pinned build-artifact manifest.

3. Certify two fresh clones from each template. Deployment refuses missing, failed, stale, or different-PVE-version evidence.

   ```bash
   Tools/Proxmox/Certify-WindowsTemplate.sh --os server-2025 --site LabConfig/site.json
   sudo Tools/Proxmox/Certify-WindowsTemplate.sh --os server-2025 --site LabConfig/site.json --apply
   Tools/Proxmox/Certify-WindowsTemplate.sh --os windows-11 --site LabConfig/site.json
   sudo Tools/Proxmox/Certify-WindowsTemplate.sh --os windows-11 --site LabConfig/site.json --apply
   ```

4. Review and apply a deployment.

   ```bash
   Tools/Proxmox/Deploy-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json
   sudo Tools/Proxmox/Deploy-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --apply
   ```

5. Complete the credential-requiring AD phases interactively in the relevant Windows guests. The first Cloudbase-Init pass records these as pending instead of retaining a password. Start with `Scripts/Initialize-LabDomain.ps1`, then use offline-domain-join blobs or a runtime `PSCredential` with `Scripts/Invoke-LabBootstrap.ps1`. Activation can be performed locally through QEMU Guest Agent with `Tools/Proxmox/Activate-LabGuests.sh`, or after domain enrollment with `Scripts/Invoke-LabWindowsActivation.ps1`.

6. Validate. Required failures produce a nonzero exit status; live runs write JSON and JUnit evidence.

   ```bash
   Tools/Proxmox/Test-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --phase full
   ```

7. Back up before a recovery drill or removal.

   ```bash
   Tools/Proxmox/Backup-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json
   Tools/Proxmox/Remove-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json
   ```

## Safety model

- All host mutations require `--apply`; removal additionally requires `--confirm <demo>-<profile>`.
- VMs must carry the `wslab` ownership tag and match the canonical name before they can be reconciled, backed up, or removed.
- VM IDs, names, IP addresses, site capacity, template IDs, bridge mappings, VLANs, and profile counts are checked before deployment.
- Definitions reject keys that resemble passwords, credentials, secrets, or tokens.
- Secure Boot, TPM 2.0, QEMU Guest Agent, Cloudbase-Init, firewall defaults, SMB hardening, Defender, audit policy, Windows LAPS, Windows Event Forwarding, and role-aware baselines are supported and validated as required controls. OpenSSH is optional and is installed only after a reachable update source or offline Features on Demand media is available.
- App Control for Business begins in audit mode. Cloud and GPU claims remain disabled unless explicitly configured and verified.

## Repository map

- `LabConfig/`: versioned definitions, schemas, and the site example
- `Tools/Proxmox/`: template, deploy, validate, backup, test, and remove commands
- `packer/windows/`: Server 2025, Server 2022, and Windows 11 template source
- `Scripts/WindowsServerLab/`: shared PowerShell module
- `Scripts/`: phased guest, policy, security, operations, and compatibility commands
- `Tests/`: Pester and Linux host tests
- `docs/`: execution, compatibility, certification, security, and recovery runbooks
- `Demo/`: scenario-specific entry points and documentation

## Documentation

- [Execution contexts](docs/EXECUTION_CONTEXT.md)
- [Compatibility and sizing](docs/COMPATIBILITY.md)
- [Six-VM smoke startup](docs/SMOKE_STARTUP.md)
- [Generated canonical inventory](docs/generated/INVENTORY.md)
- [Security model and limitations](docs/SECURITY_MODEL.md)
- [AD endpoint access controls](docs/ACCESS_CONTROL.md)
- [Machine enrollment and Group Policy refresh](docs/MACHINE_ENROLLMENT.md)
- [Printer and file-sharing policies](docs/RESOURCE_SHARING.md)
- [Runtime-only Windows activation](docs/WINDOWS_ACTIVATION.md)
- [Live certification gates](docs/LIVE_CERTIFICATION.md)
- [Backup and recovery](docs/BACKUP_RECOVERY.md)
- [Server 2022 baseline](docs/SERVER_2022_BASELINE.md)
- [Asgard quick start](Demo/Asgard/Guides/QUICK_START_ASGARD.md)
- [Olympus quick start](Demo/Olympus/Guides/QUICK_START_OLYMPUS.md)

## Validation status

Static validation covers the 6-, 7-, and 30-VM inventories, deterministic command generation, shell syntax, schemas, PowerShell parsing/analysis, Pester, documentation links, secret scanning, and release packaging. Live Proxmox 9.2 and 8.4 certification still requires operator-provided hosts, networking, media, licenses, and capacity; see the certification runbook before applying a compatibility label.

Licensed under the [MIT License](LICENSE).
