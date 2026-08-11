# Windows Server 2022 baseline

Download the approved Microsoft Security Compliance Toolkit Server 2022 baseline through the organization's artifact process. Record its immutable source and SHA-256 digest; do not commit the archive.

On each Server 2022 guest, apply the local role baseline:

```powershell
$hash = '64_HEX_CHARACTERS_FROM_APPROVED_ARTIFACT_RECORD'
C:\ProgramData\WindowsServerLab\Scripts\Set-LabSecurityBaseline.ps1 `
  -ServerRole MemberServer `
  -SctBaselinePath C:\SecureStaging\WindowsServer2022SecurityBaseline.zip `
  -SctBaselineSha256 $hash
```

The module verifies the archive, extracts to a unique temporary directory, finds the role-specific backup and bundled `LGPO.exe`, imports it, applies common hardening, and removes temporary data. Domain-wide import is separately available through `Import-Server2022SecurityBaseline.ps1` on a domain controller.

Reboot and rerun full compliance. A verified download alone is not evidence that a baseline was applied.
