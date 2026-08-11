# Olympus v2 quick start

Follow the common [project quick start](../../../README.md), selecting `olympus` in each command.

## Capacity and topology

- Smoke: 6 VMs, 11 vCPU, 17,408 MB maximum RAM, 456 GB provisioned storage
- Core: 7 VMs, 24 vCPU, 53,248 MB RAM, 1,760 GB provisioned storage
- Full: 30 VMs, 80 vCPU, 167,936 MB RAM, 4,000 GB provisioned storage
- Default domain: `ad.olympus.test`
- AI/ML network: `10.20.60.0/24`, mapped to an operator-supplied bridge/VLAN

```bash
Tools/Proxmox/Validate-LabConfig.sh --demo olympus --profile smoke --site LabConfig/site.json
Tools/Proxmox/Deploy-Lab.sh --demo olympus --profile smoke --site LabConfig/site.json
Tools/Proxmox/Deploy-Lab.sh --demo olympus --profile smoke --site LabConfig/site.json --apply
```

The smoke profile contains one ordinary client, core contains two, and the specialized `aiml-client` workstations are in the full profile. See the [six-VM startup runbook](../../../docs/SMOKE_STARTUP.md) before applying the plan.

## Configure the domain

On `ZEUS-DC01`, use an elevated Windows PowerShell 5.1 session:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Initialize-LabDomain.ps1 -Demo olympus -Profile smoke -CreatePrivilegedAccounts -Restart
C:\ProgramData\WindowsServerLab\Scripts\Set-LabDomainPolicy.ps1 -Demo olympus -ConfigureLaps -ConfigureAccessControls -ConfigurePrintPolicy
```

The same group-filtered camera, microphone, USB storage, wallpaper, Control Panel, command prompt, registry, Store, OneDrive, and RDP clipboard controls are available through `Set-LabAccessControl.ps1`; see the [access-control runbook](../../../docs/ACCESS_CONTROL.md).

Background Group Policy refresh is configured automatically. Use the hypervisor-independent `Set-LabMachineEnrollment.ps1` workflow for physical computers or VMs created outside Proxmox; see the [machine-enrollment runbook](../../../docs/MACHINE_ENROLLMENT.md).

Use the [resource-sharing runbook](../../../docs/RESOURCE_SHARING.md) to publish printers and create group-controlled encrypted file shares.

Complete replica promotion and member joins with runtime credentials or short-lived offline join blobs, then apply the server baseline.

After every selected machine is domain-enrolled and has rerun its post-join bootstrap, activate the profile from a domain administrative machine. This prompts securely for both product classes and retains neither key:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabWindowsActivation.ps1 -Action Activate -Demo olympus -Profile smoke -Scope All
```

See the [activation runbook](../../../docs/WINDOWS_ACTIVATION.md) for named secret-vault references and status-only auditing.

## Enable the optional AI/ML feature pack

For the full profile, create an artifact manifest that validates against `LabConfig/schema/aiml-artifacts.schema.json`. Every package must use HTTPS, a fixed filename, installer type, arguments, and a SHA-256 digest. On each intended AI/ML workstation:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Install-OlympusAIMLWorkstation.ps1 -ArtifactManifestPath C:\SecureStaging\aiml-artifacts.json -HealthPort 8888
```

Use `-RequireGpu` only after the site explicitly configures passthrough. The script fails if a required GPU is absent. Cloud integration is outside the default feature pack.

## Validate

```bash
Tools/Proxmox/Test-Lab.sh --demo olympus --profile smoke --site LabConfig/site.json --phase full
```

For a full certification run, select `--profile full`. Required failures return nonzero and live runs produce JSON/JUnit evidence. Follow the [live certification runbook](../../../docs/LIVE_CERTIFICATION.md) before claiming Proxmox compatibility.
