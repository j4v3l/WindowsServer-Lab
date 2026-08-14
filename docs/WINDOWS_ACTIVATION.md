# Windows activation

Windows product keys are runtime secrets. Never put them in `lab.json`, `site.json`, HCL, Packer variables, Cloud-Init metadata, shell environment variables, command arguments, transcripts, tickets, reports, or Terraform state. CI rejects committed product-key-shaped values.

The Windows 11 template selects Windows 11 Education by image name. Server template construction selects Server 2025 Desktop Experience. Templates are not activated; each clone is activated separately.

## Activate through QEMU Guest Agent

Before or after domain enrollment, run on the Proxmox node as root. The command prompts without echo and forwards each key only through guest-agent standard input:

```bash
Tools/Proxmox/Activate-LabGuests.sh --site LabConfig/site.json --action activate
sudo Tools/Proxmox/Activate-LabGuests.sh --site LabConfig/site.json --action activate --apply
```

Use `--action status --apply` to audit all six machines without requesting or changing a key. The report contains machine identity, product class, status, and a redacted exit code—never key material.

## Activate through domain PowerShell remoting

After domain enrollment, run from an administrative Windows machine. It prompts securely once per required product class and uses FQDNs with Kerberos:

```powershell
& 'C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabWindowsActivation.ps1' `
  -Action Activate `
  -Scope All
```

Use `-Scope Servers` for the five server roles, or `-Action Status` for an audit. For an approved `Microsoft.PowerShell.SecretManagement` vault, supply only lookup names:

```powershell
& 'C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabWindowsActivation.ps1' `
  -Action Activate `
  -Scope All `
  -SecretVaultName LabOperations `
  -ServerProductKeySecretName WindowsServer2025 `
  -Windows11EducationProductKeySecretName Windows11Education
```

Vault contents and recovery material remain outside the repository. The local activation command validates edition, installs the key through the Windows licensing CIM provider, requests activation, clears the full key from the registry, and checks `LicenseStatus`. Licensing entitlement and available MAK activations remain the operator's responsibility.
