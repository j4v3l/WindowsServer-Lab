# Execution contexts

| Context | Commands | Required privilege |
|---|---|---|
| Proxmox node (Bash) | `Tools/Proxmox/*.sh`, Packer | Normal user for plans; root for `--apply` |
| Windows guest (Windows PowerShell 5.1) | `Scripts/*.ps1`, shared module | Elevated local/domain administrator as documented |
| CI runner | schemas, ShellCheck, Pester, PSScriptAnalyzer, Packer syntax, links, secrets | Ephemeral runner only |

Do not run Proxmox `qm`, `pvesm`, `vzdump`, or `pvesh` commands inside a guest. Do not run AD DS/GPO cmdlets on the Proxmox host.

All host commands plan by default. `Deploy-Lab.sh`, `Backup-Lab.sh`, and template building mutate state only with `--apply`. `Remove-Lab.sh` additionally needs the exact confirmation string and validates ownership before destruction.

Credential-requiring guest phases are intentionally interactive or accept `SecureString`, `PSCredential`, or short-lived offline-domain-join files. They do not accept a plaintext password parameter.

`Set-LabMachineEnrollment.ps1` can run on a physical or virtual Windows endpoint from an extracted release/repository or from the installed `C:\ProgramData\WindowsServerLab` layout. Enrollment requires elevated local administration plus a delegated domain-join credential. Disenrollment additionally requires confirmed local-administrator access; AD object disable/delete operations require the ActiveDirectory RSAT module.
