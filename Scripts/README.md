# Windows guest scripts

Run these scripts inside Windows guests with Windows PowerShell 5.1. Proxmox host automation is under `Tools/Proxmox`.

## v2 entry points

| Script | Purpose |
|---|---|
| `Initialize-LabDomain.ps1` | Securely prompt for DSRM/demo-user material and begin the primary forest phase |
| `Invoke-LabBootstrap.ps1` | Reconcile a canonical VM role, promotion/join state, and optional baseline |
| `New-LabOfflineDomainJoin.ps1` | Create an ACL-restricted, short-lived domain-join blob |
| `Set-LabDomainPolicy.ps1` | Apply explicit GPO registry mappings, read them back, link the GPO, and configure Windows LAPS |
| `Set-LabAccessControl.ps1` | Initialize group-filtered endpoint GPOs and grant/revoke camera, USB, wallpaper, and other access |
| `Test-LabAccessControl.ps1` | Verify a selected control in the endpoint's effective HKLM/HKCU policy and emit JSON evidence |
| `Set-LabGroupPolicyRefresh.ps1` | Configure and read back native background user/computer GPO refresh with randomized load spreading |
| `Test-LabGroupPolicyRefresh.ps1` | Verify effective refresh registry mappings, Group Policy Client health, and resultant policy on an endpoint |
| `Set-LabMachineEnrollment.ps1` | Enroll, inspect, or safely disenroll a physical or virtual Windows workstation/member server |
| `Set-LabWindowsActivation.ps1` | Activate or audit one supported machine with runtime-only product-key handling |
| `Invoke-LabWindowsActivation.ps1` | Activate or audit every server or all machines in a canonical profile over secure remoting |
| `Enable-LabPowerShellRemoting.ps1` | Enable domain-only, local-subnet, Kerberos-only remoting for fleet operations |
| `Set-LabPrintPolicy.ps1` | Restrict Point and Print to the canonical server and manage print deny/admin groups |
| `Set-LabSharedPrinter.ps1` | Install a checksum-verified package-aware driver and publish a secured shared printer in AD |
| `Set-LabPrinterConnection.ps1` | Add or remove a verified canonical shared-printer connection on any joined endpoint |
| `Set-LabFileSharePolicy.ps1` | Create per-share read/change/deny groups, harden SMB policy, and manage user access |
| `Set-LabSharedFolder.ps1` | Create an encrypted, access-based SMB share with matching share and NTFS ACLs |
| `Set-LabSecurityBaseline.ps1` | Apply Server 2025 OSConfig or pinned Server 2022 SCT plus common hardening |
| `Test-LabCompliance.ps1` | Emit JSON required-control evidence and fail nonzero on blockers |
| `Enable-LabEventForwarding.ps1` | Configure a source-initiated WEF collector subscription |
| `Start-LabSystemStateBackup.ps1` | Start and verify a DC System State backup |
| `Start-LabFileBackup.ps1` | Start and verify a file-server backup |
| `Invoke-LabPatchOrchestration.ps1` | Plan or apply local Windows updates with JSON evidence and reboot signaling |
| `Test-LabFileRestore.ps1` | Restore a file backup to an alternate path and record drill evidence |
| `Set-LabManagedServiceAccount.ps1` | Create and install the IIS gMSA without retaining a service password |
| `Import-Server2022SecurityBaseline.ps1` | Import pinned SCT GPO backups at domain scope |
| `Install-OlympusAIMLWorkstation.ps1` | Install checksum-pinned AI/ML artifacts and expose local health evidence |

Shared implementation lives in `WindowsServerLab/WindowsServerLab.psm1`. Template builds copy the module and canonical definitions to `C:\ProgramData\WindowsServerLab`.

## Credential rules

No v2 command accepts plaintext passwords. Use interactive `Read-Host -AsSecureString`, `PSCredential`, a runtime secret provider, or a protected offline-domain-join blob. Delete staged blobs and baseline archives after their audited use.

## Legacy compatibility

Older names such as `Create-LabUsers.ps1`, `Lab-FinishSetup.ps1`, the group-policy managers, demo deployment scripts, and security-audit scripts are one-major-version shims. They identify the v2 replacement and do not retain duplicate or simulated implementations.

See [execution contexts](../docs/EXECUTION_CONTEXT.md), [security model](../docs/SECURITY_MODEL.md), and [live certification](../docs/LIVE_CERTIFICATION.md).
