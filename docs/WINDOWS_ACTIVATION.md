# Windows activation

Windows product keys are runtime secrets. Do not put them in a lab definition, site file, Packer variable, Cloud-Init snippet, shell environment, command argument, transcript, ticket, or report. The repository rejects any committed value shaped like a complete Windows product key.

The Windows 11 Packer build selects `Windows 11 Education` by image name. Server templates select the Desktop Experience image currently defined by the pinned build configuration. Product keys are installed only after each VM is cloned, preventing the reusable template from retaining or activating a key.

## Activate locally through Proxmox

Before domain enrollment, a root operator on the Proxmox node can use QEMU Guest Agent. The command prompts without echo and forwards each key only through guest-agent standard input; it never places a key in a command argument, environment variable, file, report, or retained Cloud-Init data.

```bash
Tools/Proxmox/Activate-LabGuests.sh --demo asgard --profile smoke --site LabConfig/site.json --action activate
Tools/Proxmox/Activate-LabGuests.sh --demo asgard --profile smoke --site LabConfig/site.json --action activate --apply
```

## Activate a profile interactively

Run from a domain administrative machine after all selected guests have completed their post-join bootstrap. The command prompts securely once for the server key and, with `-Scope All`, once for the Windows 11 Education key:

```powershell
& 'C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabWindowsActivation.ps1' `
  -Action Activate `
  -Demo asgard `
  -Profile smoke `
  -Scope All
```

Use `-Scope Servers` to target only server roles. Run the same command with `-Action Status` to audit licensing without requesting or changing a key.

The fleet command uses FQDNs and explicit Kerberos authentication. Guest bootstrap enables WinRM only after domain join, disables Basic, CredSSP, certificate, and Negotiate authentication, rejects unencrypted messages, and limits the inbound firewall rule to the Domain profile and local subnet.

## Use a registered secret vault

For unattended operator runs, install and register a vault compatible with `Microsoft.PowerShell.SecretManagement`. Store each key as a `SecureString`, then pass only its non-sensitive lookup name:

```powershell
& 'C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabWindowsActivation.ps1' `
  -Action Activate `
  -Demo asgard `
  -Profile full `
  -Scope All `
  -SecretVaultName LabOperations `
  -ServerProductKeySecretName WindowsServer `
  -Windows11EducationProductKeySecretName Windows11Education
```

Secret vault contents and recovery material belong outside the repository. Do not use plaintext environment variables as a substitute.

## Behavior and evidence

The local command validates the installed edition, installs the key through the Windows Software Licensing CIM provider, requests activation, clears the full key from the registry, and then checks `LicenseStatus`. Reports contain only the machine, edition class, and activation state. They never contain a complete or partial product key.

Activation is idempotent for already licensed machines. A key that does not apply to the installed Windows version or edition fails that machine and makes the fleet command exit nonzero. Licensing entitlement and available MAK activations remain the operator's responsibility; cloning a licensed template does not license its clones.
