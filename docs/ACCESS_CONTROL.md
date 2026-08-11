# AD endpoint access controls

WindowsServerLab uses one AD security group and one security-filtered GPO per control. Membership is the supported interface: adding an object applies the denial or lock, and removing it stops this lab GPO from applying. The workflow never edits individual endpoints remotely and does not store credentials.

## Initialize once per domain

Run on a domain controller in elevated Windows PowerShell 5.1 after `Initialize-LabDomain.ps1` has created the canonical OUs and users:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 `
  -Demo asgard `
  -Initialize
```

To lock selected users to an approved image as well as preventing wallpaper changes, host the image on a UNC path that domain users and computers can read before sign-in:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 `
  -Demo asgard `
  -Initialize `
  -WallpaperPath '\\HEIMDALL-FS01\Tools\Branding\asgard.jpg'
```

Initialization is declarative and rerunnable. It creates or reconciles every GPO, reads each registry policy value back, gives `Authenticated Users` read permission, grants only the matching control group permission to apply the GPO, and verifies its OU link. Computer controls link to `OU=Workstations`; user controls link to the demo's base OU.

## Give or remove access

`Deny` adds the target to a control group. `Allow` removes it from that group:

```powershell
# Hardware policy: a canonical user name resolves to that user's demo workstation.
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 `
  -Demo asgard -Identity thor.engineer -Control Camera -Access Deny -RefreshPolicy

# A computer name is also accepted for computer-scoped controls.
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 `
  -Demo asgard -Identity THOR-WS01 -Control USBStorage -Access Allow -RefreshPolicy

# User policy: prevent and later permit wallpaper changes.
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 `
  -Demo asgard -Identity thor.engineer -Control Wallpaper -Access Deny -RefreshPolicy
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 `
  -Demo asgard -Identity thor.engineer -Control Wallpaper -Access Allow -RefreshPolicy
```

Camera, microphone, USB storage, Store, OneDrive, and RDP clipboard are computer-scoped: naming a user is a convenience that resolves their canonical demo workstation, and the resulting policy affects everyone who uses that workstation. Wallpaper, Control Panel, command prompt, and registry-tool controls are user-scoped and follow the user across in-scope workstations.

The available control IDs are:

| Control | Scope | Denial or lock |
|---|---|---|
| `Camera` | Computer | Camera device and app access |
| `Microphone` | Computer | Application microphone access |
| `USBStorage` | Computer | All removable-storage classes |
| `Wallpaper` | User | Wallpaper changes; optionally enforces a UNC image |
| `ControlPanel` | User | Control Panel and Windows Settings |
| `CommandPrompt` | User | `cmd.exe` |
| `RegistryTools` | User | Registry editing tools |
| `WindowsStore` | Computer | Microsoft Store |
| `OneDrive` | Computer | OneDrive synchronization |
| `RdpClipboard` | Computer | Clipboard redirection in RDP sessions |

`USBStorage` intentionally blocks removable storage, not every physical USB controller. Disabling all USB controllers can also disable keyboards, mice, smart-card readers, cameras, and recovery devices. Apply broader device-installation or firmware controls only after testing hardware IDs on the exact endpoint model.

You can also manage membership with standard AD tools. The catalog in `LabConfig\policies\access-controls.json` contains the exact group names, GPO names, scopes, refresh requirements, and policy mappings. Keep catalog changes schema-valid and rerun initialization after an approved change.

## Verify the endpoint

Group/GPO read-back proves the domain configuration. Effective policy must be checked on the affected workstation after replication and policy refresh. Run user controls in the affected user's session:

```powershell
gpupdate.exe /force
C:\ProgramData\WindowsServerLab\Scripts\Test-LabAccessControl.ps1 `
  -Control Camera -ExpectedAccess Deny

C:\ProgramData\WindowsServerLab\Scripts\Test-LabAccessControl.ps1 `
  -Control Wallpaper -ExpectedAccess Deny `
  -WallpaperPath '\\HEIMDALL-FS01\Tools\Branding\asgard.jpg'

gpresult.exe /h C:\Windows\Temp\wslab-gpresult.html
```

The test writes structured JSON evidence and returns a nonzero exit code on failure. Camera, microphone, and USB changes may require a restart. User restrictions may require sign-out. Other policies with higher precedence can still deny a feature after this lab's membership is removed; `Allow` is therefore “remove this lab denial,” not an override of organization policy.

PowerShell/application allow-list enforcement is deliberately outside these convenience controls. Use the repository's App Control for Business audit-to-enforcement workflow instead of treating execution policy, `DisableCMD`, or AppLocker alone as a security boundary.
