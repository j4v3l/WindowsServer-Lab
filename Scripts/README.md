# Guest PowerShell operations

These commands consume `C:\ProgramData\WindowsServerLab\LabConfig\lab.json`, the same inventory used by Terraform. The five core server roles are singletons; additional `member-server` and `client` entries scale through that inventory without alternate deploy scripts or profiles.

| Script | Purpose |
|---|---|
| `Invoke-LabBootstrap.ps1` | Stage-aware guest convergence for AD, DNS, DHCP, joins, roles, and security |
| `Initialize-LabDomain.ps1` | Interactive primary forest entry point |
| `Initialize-LabDataDisks.ps1` | Initialize only disks declared in the canonical inventory |
| `Invoke-LabWindowsActivation.ps1` | Audit or activate the five servers or all six machines over Kerberos |
| `Set-LabSecurityBaseline.ps1` | Apply Server 2025 OSConfig and common hardening |
| `Set-LabClientSecurityBaseline.ps1` | Apply the Windows 11 baseline |
| `Set-LabDomainPolicy.ps1` | Reconcile domain security, LAPS, access, print, and refresh policy |
| `Set-LabAccessControl.ps1` | Manage group-filtered endpoint restrictions |
| `Set-LabFileSharePolicy.ps1` / `Set-LabSharedFolder.ps1` | Reconcile AD, SMB, and NTFS file access |
| `Set-LabPrintPolicy.ps1` / `Set-LabSharedPrinter.ps1` | Reconcile trusted print policy and the shared queue |
| `Set-LabMachineEnrollment.ps1` | Enroll or remove external Windows endpoints without a hypervisor dependency |
| `Test-LabCompliance.ps1` | Return pass/fail guest evidence for acceptance |
| `Start-LabSystemStateBackup.ps1` | Create Windows System State backup evidence |
| `Start-LabFileBackup.ps1` / `Test-LabFileRestore.ps1` | Back up and test restore of file data |

Domain, DSRM, user, and activation secrets are `SecureString`/`PSCredential` inputs or interactive prompts. They are never accepted as plaintext configuration values.
