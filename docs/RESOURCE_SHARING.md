# Printer and file-sharing policies

WindowsServerLab treats visibility and authorization as separate controls. A printer can be published in Active Directory for discovery by every joined machine while selected users are denied printing. An SMB share has a stable UNC path while read, change, deny, and removal decisions are enforced by matching AD, share, and NTFS permissions.

The canonical `HEIMDALL-FS01` file server also acts as the print server. Organization-specific print hardware, signed drivers, storage volumes, quotas, classification, and retention remain operator inputs.

## Shared printer

### 1. Initialize domain print policy

Run on a domain controller:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrintPolicy.ps1 `
  -Initialize
```

This creates `ACL-Print-Deny` and `ACL-Print-Admin`, then creates and verifies `WSLAB-v2-Print-Policy`. Point and Print is restricted to the canonical FQDN, package-aware drivers are required, driver installation stays administrator-only, and warning/elevation bypass values remain disabled. Microsoft recommends configuring both ordinary and package Point-and-Print restrictions for approved servers because they are independent controls. See [Microsoft's printer Group Policy guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-server/printing/use-group-policy-to-control-ad-printer).

`Set-LabDomainPolicy.ps1 -ConfigurePrintPolicy` performs the same initialization during the normal domain-policy phase.

### 2. Publish the physical or network printer

Stage the complete vendor driver package on the canonical file server. Use a vendor-authenticated package-aware driver; the command verifies the supplied INF hash, lets Windows validate package signing during staging, and rejects a driver reported as non-package-aware.

Run on the canonical file server:

```powershell
$driverHash = (Get-FileHash C:\SecureStaging\Printer\driver.inf -Algorithm SHA256).Hash

C:\ProgramData\WindowsServerLab\Scripts\Set-LabSharedPrinter.ps1 `
  -PrinterName 'Main Office Printer' `
  -ShareName MainPrinter `
  -DriverName 'Exact installed vendor driver name' `
  -PrinterAddress 10.10.40.25 `
  -Location 'Main Office / Floor 1' `
  -DriverInfPath C:\SecureStaging\Printer\driver.inf `
  -DriverInfSha256 $driverHash
```

The command installs the Print Server role when needed, creates the TCP/IP port, shares the queue, publishes it in AD, applies printer SDDL, and reads the resulting queue and ACL back. `Authenticated Users` can print by default, `ACL-Print-Deny` has an overriding deny ACE, `ACL-Print-Admin` can manage the queue, and built-in administrators retain full control. Microsoft documents the underlying print access masks in its [`Win32_Printer.SetSecurityDescriptor` guidance](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/setsecuritydescriptor-method-in-class-win32-printer).

Publishing makes the queue discoverable in the Windows Add Printer search. It does not silently install a connection. Add or remove the canonical connection on any joined physical or virtual endpoint with:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrinterConnection.ps1 `
  -Action Add -ShareName MainPrinter

C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrinterConnection.ps1 `
  -Action Remove -ShareName MainPrinter
```

For automatic deployment to an OU, deploy the published queue from Print Management to a Group Policy after validating the driver and queue. Windows' deployed-printer extension is the supported mechanism for making the connection appear automatically on targeted computers or for targeted users. See Microsoft's [Deployed Printer Connections overview](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpdpc/378fc637-aa56-4c42-93ae-04931b19552e). The repository does not hand-edit SYSVOL preference XML or GPO extension metadata.

### 3. Grant or remove print access

All authenticated users can print unless directly or indirectly placed in the deny group:

```powershell
# Deny and later restore ordinary printing.
C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrintPolicy.ps1 `
  -Identity thor.engineer -Permission Print -Access Deny
C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrintPolicy.ps1 `
  -Identity thor.engineer -Permission Print -Access Allow

# Delegate and later remove queue administration.
C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrintPolicy.ps1 `
  -Identity thor.engineer -Permission Manage -Access Allow
C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrintPolicy.ps1 `
  -Identity thor.engineer -Permission Manage -Access Deny
```

`Print/Deny` adds the user to `ACL-Print-Deny`; `Print/Allow` removes that denial. `Manage/Allow` and `Manage/Deny` add or remove delegated administration. Group-token changes normally require sign-out before the print server sees the new authorization.

## Managed file shares

### 1. Create groups and domain SMB policy

Run on a domain controller for each share:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1 `
  -ShareName CompanyData -Initialize
```

This creates three domain-local security groups with deterministic names, such as `FS-COMPANYDAT-R`, `FS-COMPANYDAT-RW`, and `FS-COMPANYDAT-D`. Supply explicit `-ReadGroupName`, `-ChangeGroupName`, and `-DenyGroupName` values when two long share names would otherwise produce the same ten-character token. Existing groups with incompatible scope or a description owned by another share are rejected.

The shared `WSLAB-v2-FileShare-Policy` requires SMB client/server signing and disables insecure guest access. The GPO values and enabled OU link are read back. Share encryption is additionally required on each managed share.

Add `-DefaultReadForDomainUsers` only for content intended to be readable by everyone. This nests `Domain Users` in the share's read group while the deny group remains an exception mechanism:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1 `
  -ShareName PublicDocs -Initialize -DefaultReadForDomainUsers
```

### 2. Create the share on the file server

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabSharedFolder.ps1 `
  -ShareName CompanyData `
  -Path D:\Shares\CompanyData `
  -Description 'Controlled company data'
```

The resulting `\\HEIMDALL-FS01.ad.asgard.test\CompanyData` path is stable and reachable from every correctly routed joined machine. Authorization still determines whether its contents can be opened. The command enables encryption and access-based enumeration, removes broad `Everyone`/`Authenticated Users` share grants, adds read/change/deny share permissions, sets matching inheritable NTFS rules, and reads both layers back.

The script refuses to adopt a nonempty, previously unmanaged directory by default. Use `-AdoptExistingPath` only after a backup and ACL review. Existing descendants with inheritance disabled are reported for separate remediation rather than silently rewritten.

### 3. Assign file access

```powershell
# Read only
C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1 `
  -ShareName CompanyData `
  -Identity thor.engineer -Permission Read

# Read and modify
C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1 `
  -ShareName CompanyData `
  -Identity thor.engineer -Permission Change

# Explicit deny, or remove all managed membership
C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1 `
  -ShareName CompanyData `
  -Identity thor.engineer -Permission Deny
C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1 `
  -ShareName CompanyData `
  -Identity thor.engineer -Permission Remove
```

Assignments are exclusive: selecting `Read`, `Change`, `Deny`, or `Remove` reconciles direct membership across all three groups and verifies the result. `Remove` removes direct resource groups; if `Domain Users` has default read access, use `Deny` to create an exception. A deny membership overrides allow permissions inherited through another group. Sign out and back in after membership changes.

## Acceptance checks

For every release candidate:

1. Find the published printer from two separate joined machines.
2. Connect and print a test page as an ordinary user.
3. Add that user to the print deny group, renew their token, and prove printing fails while discovery remains available.
4. Delegate print administration to a test administrator and verify ordinary users cannot manage another user's job.
5. Test file read, change, deny, and remove states from a physical endpoint and a VM.
6. Verify SMB encryption/signing, access-based enumeration, share ACLs, NTFS ACLs, and backup coverage.
7. Retain JSON reports, `gpresult`, print-service logs, and SMB audit evidence.

Printer licenses, consumable monitoring, pull-print authentication, print accounting, quotas, DFS namespaces, data classification, offline files, and organization retention rules are integrations, not silently assumed lab features.
