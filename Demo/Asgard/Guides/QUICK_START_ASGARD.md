# Asgard v2 quick start

## 1. Preflight on the Proxmox node

```bash
cp LabConfig/site.example.json LabConfig/site.json
# Edit node, storage, VLAN/bridge mappings, SSH key paths, and proven capacity.
Tools/Proxmox/Validate-LabConfig.sh --demo asgard --profile smoke --site LabConfig/site.json
Tools/Proxmox/Configure-LabNetwork.sh --site LabConfig/site.json
```

The default smoke requirement is 6 VMs, 11 vCPU, 17,408 MB maximum RAM (14,336 MB balloon minimum), and 456 GB thin-provisioned storage. Servers use `vmbr1`/VLAN 90 and the client uses `vmbr1`/VLAN 100; `nic1` must have carrier on a tagged trunk. Core and full remain blocked until their management and DMZ mappings are explicitly supplied. Follow the [six-VM startup runbook](../../../docs/SMOKE_STARTUP.md) for host inspection, bridge safeguards, and execution contexts.

## 2. Build templates

Use licensed Server 2025 and current Windows 11 media plus the VirtIO ISO configured in `site.json`. Set the required `PKR_VAR_*` values from a runtime secret provider, then rerun each reviewed command with `--apply`. Server 2022 is needed only for the separate compatibility gate.

```bash
Tools/Proxmox/Build-WindowsTemplate.sh --os server-2025 --iso /media/server-2025.iso --iso-sha256 SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json
Tools/Proxmox/Build-WindowsTemplate.sh --os windows-11 --iso /media/windows-11.iso --iso-sha256 SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json
```

## 3. Configure the isolated bridge and run the lab

```bash
Tools/Proxmox/Configure-LabNetwork.sh --site LabConfig/site.json --apply
Tools/Proxmox/Start-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --activate
Tools/Proxmox/Start-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --activate --apply
```

The wrapper creates or reconciles owned VMs, configures AD/services/policies in dependency order, prompts without echo for AD and activation credentials, and validates through QEMU Guest Agent. It refuses name/ID conflicts and stale or missing template evidence.

## 4. Operate Windows policy

The startup wrapper has already initialized and read back the domain policies. Later access changes can be made on `ODIN-DC01` with an elevated domain administration identity:

```powershell
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 -Demo asgard -Identity ODIN-WS01 -Control Camera -Access Allow -RefreshPolicy
C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1 -Demo asgard -Identity odin.chief -Control Wallpaper -Access Allow -RefreshPolicy
```

Use `Set-LabAccessControl.ps1` to grant or revoke camera, microphone, USB storage, wallpaper changes, Control Panel, command prompt, registry tools, Microsoft Store, OneDrive, and RDP clipboard access. See the [access-control runbook](../../../docs/ACCESS_CONTROL.md) for examples and effective-policy checks.

`Set-LabDomainPolicy.ps1` also enables verified native background Group Policy refresh. Physical computers and non-Proxmox VMs can be joined or removed with `Set-LabMachineEnrollment.ps1`; follow the [machine-enrollment runbook](../../../docs/MACHINE_ENROLLMENT.md).

Shared printers and folders use separate visible-resource and access-policy phases; follow the [resource-sharing runbook](../../../docs/RESOURCE_SHARING.md).

The same access script handles microphone, USB storage, Control Panel, command prompt, registry tools, Microsoft Store, OneDrive, and RDP clipboard. A hardware printer queue is created only after supplying a real address and a checksum-verified signed package-aware driver; the trusted print server and deny/admin policies are already configured.

## 5. Validate and protect

```bash
Tools/Proxmox/Test-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --phase full
Tools/Proxmox/Backup-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json
```

Only add `--apply` to backup after reviewing the plan. Domain controllers additionally require Windows System State backups and an isolated restore drill. See the [certification](../../../docs/LIVE_CERTIFICATION.md) and [recovery](../../../docs/BACKUP_RECOVERY.md) runbooks.
