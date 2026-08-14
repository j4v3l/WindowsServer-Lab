# Machine enrollment and Group Policy refresh

The enrollment workflow is independent of Proxmox. It supports physical computers, laptops, third-party hypervisors, and Proxmox guests as long as the Windows edition can join Active Directory and the machine can reach the lab DNS and domain-controller services.

## Background Group Policy refresh

`Set-LabDomainPolicy.ps1` now configures `WSLAB-v2-GroupPolicy-Refresh` automatically. The default policy:

- refreshes computer policy every 30 minutes plus a random delay of 0–10 minutes;
- refreshes user policy every 30 minutes plus a random delay of 0–10 minutes;
- explicitly leaves background refresh enabled;
- waits for the network during foreground startup and sign-in processing;
- links only to the lab's base OU, which contains lab servers, workstations, and users.

The random offset avoids sending every endpoint to a domain controller at once. Domain controllers retain Windows' native five-minute background refresh behavior, consistent with Microsoft's [Group Policy processing guidance](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/group-policy/group-policy-processing). Security-group membership changes can still require sign-out for a user or restart for a computer because Kerberos authorization tokens must be renewed; repeatedly running `gpupdate` cannot replace that token renewal.

To change the managed interval:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabGroupPolicyRefresh.ps1 `
  -ComputerIntervalMinutes 30 `
  -ComputerRandomOffsetMinutes 10 `
  -UserIntervalMinutes 30 `
  -UserRandomOffsetMinutes 10
```

The command writes each real GPO registry mapping, reads it back, verifies the enabled OU link, and writes JSON evidence to `C:\ProgramData\WindowsServerLab\Reports\group-policy-refresh.json`. Values below 15 minutes are rejected to prevent unnecessary domain-controller load.

After the first restart/sign-in, verify effective policy on an endpoint. Run `Both` in the affected user's session; automated SYSTEM checks should use `Computer` scope:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Test-LabGroupPolicyRefresh.ps1 -Scope Both
```

The verifier checks the effective HKLM/HKCU values, Group Policy Client service, and `gpresult` status, writes JSON evidence, and exits nonzero when a required check fails.

## Prepare a new machine

Before enrollment:

1. Install a supported domain-join-capable Windows edition; Windows Home is rejected.
2. Patch the operating system and firmware, enable Secure Boot and TPM where supported, and verify a working local administrator account.
3. Copy the repository or release bundle to the machine. The script resolves the module and lab definition from either the release layout or `C:\ProgramData\WindowsServerLab`.
4. Connect the machine to a site network that can reach the lab DNS servers and domain controllers.
5. Use a delegated domain-join identity, not a Domain Admin account. Supply it interactively or as an in-memory `PSCredential`.

Preview the enrollment first:

```powershell
.\Scripts\Set-LabMachineEnrollment.ps1 `
  -Action Enroll -DeviceType Workstation `
  -ComputerName ENG-LT-042 -ConfigureDns -WhatIf
```

Apply and restart:

```powershell
$joinCredential = Get-Credential -Message 'Delegated domain-join account'
.\Scripts\Set-LabMachineEnrollment.ps1 `
  -Action Enroll -DeviceType Workstation `
  -ComputerName ENG-LT-042 -ConfigureDns `
  -DomainCredential $joinCredential -Restart
```

`Workstation` places the computer in the demo's `OU=Workstations`; `MemberServer` uses `OU=Servers`. `-ConfigureDns` derives the proper DNS servers from the canonical lab definition, or for the default Asgard site you can provide `-DnsServer 192.168.90.10,192.168.90.11`. If multiple adapters are active, select them explicitly with `-InterfaceAlias Ethernet`; the script refuses to guess and potentially rewrite a VPN or management adapter. Without `-ConfigureDns`, existing adapter settings are preserved and the connectivity preflight must already succeed.

The preflight verifies the domain LDAP SRV record and TCP reachability for Kerberos 88, RPC endpoint mapping 135, LDAP 389, and SMB 445. Site firewalls must also allow the documented AD DS dynamic RPC and DNS traffic. It refuses to move a computer directly from an unrelated domain. A successful join requires a restart; foreground Group Policy then places the machine under the baseline and background-refresh policy. The join uses the documented [`Add-Computer`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-computer?view=powershell-5.1) OU and credential interface.

For an existing joined endpoint, status and an immediate refresh are available:

```powershell
.\Scripts\Set-LabMachineEnrollment.ps1 -Action Status
.\Scripts\Set-LabMachineEnrollment.ps1 -Action Enroll -RefreshPolicy
```

For computer-scoped camera, USB, or other restrictions on an external machine, use its computer name with `Set-LabAccessControl.ps1`. External users do not have a canonical user-to-machine mapping, so explicitly name the computer.

## Disenroll safely

Before leaving the domain, prove that a local administrator account works. The confirmation switch is mandatory because cached domain credentials may stop working after unjoin:

```powershell
$unjoinCredential = Get-Credential -Message 'Delegated domain-unjoin account'
.\Scripts\Set-LabMachineEnrollment.ps1 `
  -Action Disenroll `
  -DomainCredential $unjoinCredential `
  -ConfirmLocalAdministratorAccess `
  -DirectoryDisposition Preserve `
  -Restart
```

Directory disposition choices are:

| Value | Behavior |
|---|---|
| `Preserve` | Safest default; retains the computer object that `Remove-Computer` disables automatically |
| `Disable` | Explicitly verifies/disables the retained AD computer object; requires the ActiveDirectory RSAT module |
| `Delete` | Deletes the AD computer object; requires RSAT and an exact computer-name confirmation token |

Complete deletion is intentionally explicit:

```powershell
.\Scripts\Set-LabMachineEnrollment.ps1 `
  -Action Disenroll `
  -DomainCredential $unjoinCredential `
  -ConfirmLocalAdministratorAccess `
  -DirectoryDisposition Delete `
  -ConfirmDirectoryObjectDeletion $env:COMPUTERNAME `
  -Restart
```

The script refuses to unjoin a domain that is not declared by the lab. Microsoft documents that [`Remove-Computer`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-computer?view=powershell-5.1) disables the computer account and requires a restart; the additional directory disposition makes retention or deletion explicit. If local unjoin succeeds but directory cleanup fails, the JSON report uses `failed-after-local-change` and records that restart is still required. Reports never contain credentials.

Disenrollment does not erase the endpoint, remove local data, rotate shared credentials, revoke certificates, remove management agents, or release software licenses. Those remain explicit offboarding steps appropriate to the systems integrated with the lab.
