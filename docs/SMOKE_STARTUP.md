# Six-VM smoke startup

The `smoke` profile is the smallest complete functional lab: all five Windows Server roles and one Windows 11 Education workstation.

## Allocation

| Role | vCPU | Maximum RAM | Balloon minimum | Disk |
|---|---:|---:|---:|---:|
| Primary domain controller | 2 | 3,072 MB | 2,560 MB | 64 GB |
| Secondary domain controller | 2 | 3,072 MB | 2,560 MB | 64 GB |
| File server | 2 | 2,560 MB | 2,048 MB | 64 GB OS + 56 GB data |
| Web server | 1 | 2,048 MB | 2,048 MB | 64 GB |
| Management/security server | 2 | 2,560 MB | 2,048 MB | 64 GB |
| Windows 11 test client | 2 | 4,096 MB | 3,072 MB | 80 GB |
| **Total** | **11** | **17,408 MB** | **14,336 MB** | **456 GB thin-provisioned** |

The apply-time preflight compares these allocations with current host CPU threads, currently available RAM plus the configured reserve, and free storage. It refuses to start if the host no longer fits the profile.

## 1. Configure the operator workstation

Create the ignored local files from their tracked examples:

```bash
cp LabConfig/operator.example.json LabConfig/operator.json
cp LabConfig/site.example.json LabConfig/site.json
```

Set the remote host, node, SSH account/key path, exact Proxmox ISO volume names, and verified media SHA-256 values in `operator.json`. Set storage, template IDs, network mappings, capacity, guest key paths, and the approved VirtIO SHA-256 in `site.json`. Also set `templateBuildNetwork` to an unused IPv4 address on a bridge with a working gateway and DNS. Packer uses that address for one transient build VM at a time; the wrapper checks for a live ARP conflict before creating the VM. These two local files are gitignored; definitions and secrets are not mixed.

Asgard smoke uses a dedicated, unnumbered `vmbr1` on `nic1`. Servers are tagged on VLAN 90 (`192.168.90.0/24`); the Windows client is tagged on VLAN 100 (`192.168.100.0/24`). `vmbr0` remains the Proxmox management bridge and is never edited. The switch port on `nic1` must already be a tagged trunk for VLANs 90 and 100, and the gateways must permit DNS and AD traffic from VLAN 100 to both domain controllers.

## 2. Inspect and prepare the Proxmox host

Run these from the operator workstation. Inspection is read-only. Preparation is also plan-only until `--apply` is added.

```bash
Tools/Proxmox/Inspect-RemoteHost.sh \
  --operator LabConfig/operator.json \
  --site LabConfig/site.json \
  --demo asgard \
  --profile smoke

Tools/Proxmox/Prepare-LabHost.sh \
  --operator LabConfig/operator.json \
  --site LabConfig/site.json \
  --artifacts LabConfig/build-artifacts.json
```

The tracked manifest pins Packer, VirtIO, and Cloudbase-Init to versioned HTTPS URLs and SHA-256 digests. Review updates to that manifest like dependency changes. Apply mode installs only the required host packages, installs Packer when absent or too old, adds missing verified VirtIO media, and creates a dedicated guest-bootstrap SSH keypair. It does not store Windows/API credentials.

Configure the isolated bridge separately. The command refuses `vmbr0`, the active default-route device, an uplink without carrier, or a bridge with host addressing. It backs up only its owned configuration and applies only `vmbr1`:

```bash
Tools/Proxmox/Configure-LabNetwork.sh --site LabConfig/site.json
Tools/Proxmox/Configure-LabNetwork.sh --site LabConfig/site.json --apply
```

Rerun inspection after applying preparation. All template checks remain failed until the next step finishes.

## 3. Build the two smoke templates

Place or clone this repository on the targeted Proxmox node, and copy only `LabConfig/site.json` to that working tree. Keep `operator.json` on the workstation. On the Proxmox node, either resolve the API token and temporary Windows build password from the runtime secret system, or use the automated ephemeral path below. The pinned Cloudbase-Init artifact comes from `build-artifacts.json`.

Retail/OEM media can require a key merely to select an installable edition. Create a root-only, gitignored `LabConfig/setup-keys.json` using the Microsoft-published Generic Volume License Keys (GVLKs), not your purchased activation keys:

```json
{
  "schemaVersion": 1,
  "setupKeys": {
    "server-2025": "MICROSOFT_PUBLISHED_SERVER_2025_STANDARD_GVLK",
    "server-2022": "MICROSOFT_PUBLISHED_SERVER_2022_STANDARD_GVLK",
    "windows-11": "MICROSOFT_PUBLISHED_WINDOWS_11_EDUCATION_GVLK"
  }
}
```

```bash
chmod 600 LabConfig/setup-keys.json
```

GVLKs select an edition but cannot activate retail installations. The build wrapper consumes the selected value through its private, transient bootable Windows ISO overlay and removes that overlay on exit. Actual activation remains a post-clone runtime operation. Obtain the current public values from [Microsoft's KMS client key reference](https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys).

For an operator-managed secret provider:

```bash
export PKR_VAR_proxmox_url='https://PVE_ADDRESS:8006/api2/json'
export PKR_VAR_proxmox_username='PACKER_TOKEN_ID'
read -rsp 'Packer API token: ' PKR_VAR_proxmox_token; export PKR_VAR_proxmox_token; printf '\n'
read -rsp 'Temporary Windows build password: ' PKR_VAR_windows_password; export PKR_VAR_windows_password; printf '\n'
```

Review and then apply each template build:

```bash
Tools/Proxmox/Build-WindowsTemplate.sh --os server-2025 --iso 'local:iso/SERVER_2025.iso' --iso-sha256 SERVER_2025_SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json --setup-keys LabConfig/setup-keys.json
Tools/Proxmox/Build-WindowsTemplate.sh --os windows-11 --iso 'local:iso/WINDOWS_11.iso' --iso-sha256 WINDOWS_11_SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json --setup-keys LabConfig/setup-keys.json

Tools/Proxmox/Build-WindowsTemplate.sh --os server-2025 --iso 'local:iso/SERVER_2025.iso' --iso-sha256 SERVER_2025_SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json --setup-keys LabConfig/setup-keys.json --apply
Tools/Proxmox/Build-WindowsTemplate.sh --os windows-11 --iso 'local:iso/WINDOWS_11.iso' --iso-sha256 WINDOWS_11_SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json --setup-keys LabConfig/setup-keys.json --apply
```

When running locally as root on the Proxmox node, `--ephemeral-build-secrets` instead creates a random media-build password and a four-hour root-scoped API token. The token is revoked and the password discarded when each build exits; the token's expiry limits exposure after an uncatchable process/host failure:

```bash
Tools/Proxmox/Build-WindowsTemplate.sh --os server-2025 --iso 'local:iso/SERVER_2025.iso' --iso-sha256 SERVER_2025_SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json --setup-keys LabConfig/setup-keys.json --ephemeral-build-secrets --apply
Tools/Proxmox/Build-WindowsTemplate.sh --os windows-11 --iso 'local:iso/WINDOWS_11.iso' --iso-sha256 WINDOWS_11_SHA256 --site LabConfig/site.json --artifacts LabConfig/build-artifacts.json --setup-keys LabConfig/setup-keys.json --ephemeral-build-secrets --apply
```

The wrapper downloads Cloudbase-Init, verifies the pinned installer and VirtIO media, and remasters a temporary bootable copy of the supplied Windows ISO. That overlay contains `Autounattend.xml`, volume-independent VirtIO driver discovery, WSLABDATA payloads, and their manifests while replaying the Microsoft boot catalog. It records source/generated hashes plus a deterministic digest of the template/OOBE automation and removes the credential-bearing overlay on every exit. Certification and deployment reject evidence when that automation digest no longer matches the current files, so template-affecting code changes require a rebuild and two new canaries. Purchased activation keys remain runtime-only and are never embedded in templates.

Unset all build variables when both templates finish:

```bash
unset PKR_VAR_proxmox_url PKR_VAR_proxmox_username PKR_VAR_proxmox_token PKR_VAR_windows_password
```

Build completion creates an uncertified template. Before deployment, run two sequential clone tests for each image; the command writes canonical JSON and JUnit evidence and removes its canary VM after each successful run:

```bash
Tools/Proxmox/Certify-WindowsTemplate.sh --os server-2025 --site LabConfig/site.json
Tools/Proxmox/Certify-WindowsTemplate.sh --os server-2025 --site LabConfig/site.json --apply
Tools/Proxmox/Certify-WindowsTemplate.sh --os windows-11 --site LabConfig/site.json
Tools/Proxmox/Certify-WindowsTemplate.sh --os windows-11 --site LabConfig/site.json --apply
```

## 4. Create the six VMs

Run on the Proxmox node. The first command prints the exact plan. The second creates or reconciles only tagged lab-owned VMs, starts them in dependency order, and waits for QEMU Guest Agent health:

```bash
Tools/Proxmox/Deploy-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json
Tools/Proxmox/Deploy-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --apply
```

Do not use `sudo` if already logged in as root. A rerun is expected and must make no unintended changes. HEIMDALL receives a 64-GB OS disk plus a distinct 56-GB data disk that is initialized as `D:` only when Windows confirms it is blank.

## 5. Complete AD and validate

Use the end-to-end plan first. Apply mode requires the bridge and both matching template certificates, deploys the six guests, securely prompts for the three AD passwords, configures the full dependency chain, optionally activates each correct edition, and validates through QEMU Guest Agent:

```bash
Tools/Proxmox/Start-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --activate
Tools/Proxmox/Start-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --activate --apply
```

The prompts are no-echo and the values are passed only on QEMU Guest Agent standard input. They are not placed in JSON, command arguments, Cloud-Init, reports, or retained guest files. A real printer queue remains intentionally unclaimed until a printer IP and checksum-verified package-aware signed driver are supplied. To rerun only acceptance:

```bash
Tools/Proxmox/Test-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --phase full
```

Runtime keys can be applied locally without domain credentials through `Tools/Proxmox/Activate-LabGuests.sh --action activate`; it reads keys without echo and forwards them only through QEMU Guest Agent standard input. The Kerberos fleet command remains available after domain enrollment. Camera/USB/wallpaper controls, background Group Policy refresh, physical-machine enrollment, printer publication/access, and SMB share policy are covered by the linked access, enrollment, and resource-sharing runbooks.
