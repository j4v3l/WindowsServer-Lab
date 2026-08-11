# Live certification gates

Static CI is necessary but does not certify Proxmox or Windows behavior. Run this checklist on clean operator-provided infrastructure and retain JSON/JUnit evidence.

## Current Asgard smoke status (2026-08-11)

Template certification has been performed on node `pve2`, running Proxmox VE 9.2.3:

| Template | ID | Result | Evidence timestamp |
|---|---:|---|---|
| Windows Server 2025 | 9000 | Passed two fresh canaries | 2026-08-09T15:11:36Z |
| Windows 11 Education | 9011 | Passed two fresh canaries with distinct SID and MachineGuid values | 2026-08-11T05:10:23Z |

The final host inspection verified both matching certificates, checksummed Windows/VirtIO media, the six free VM IDs, available CPU/memory/storage, no certification VM, no temporary Packer token or process, and no transient answer/install overlay. Canonical key-free JSON and JUnit evidence is retained under `/var/lib/windows-server-lab/reports/template-certifications` on the Proxmox node. The earlier Windows 11 identity failure is retained separately in that directory's root-only `history` folder.

The six-VM lab is **not yet deployed or live-certified**. The dedicated adapter `nic1` (PCI `0000:00:1f.6`, driver `e1000e`) reports no physical carrier, so the guarded network command correctly refuses to create `vmbr1`. Connect that adapter to a switch port configured as a tagged VLAN 90/100 trunk, then run:

```bash
Tools/Proxmox/Configure-LabNetwork.sh --site LabConfig/site.json --apply
Tools/Proxmox/Inspect-RemoteHost.sh --operator LabConfig/operator.json --site LabConfig/site.json --demo asgard --profile smoke
Tools/Proxmox/Start-Lab.sh --demo asgard --profile smoke --site LabConfig/site.json --activate --apply
```

Until those commands complete, AD/DNS/DHCP, guest joins, policy enforcement, service acceptance, activation, and idempotency remain pending, and no `validated-pve-9.2` lab label may be claimed.

## Per supported Proxmox version

1. Build Server 2025, Server 2022, and Windows 11 templates from checksum-verified media.
2. Deploy Asgard core and Olympus core.
3. Complete all guest phases, rerun deployment, and prove zero unintended change.
4. Run `Test-Lab.sh --phase full` and retain its JSON and JUnit files.
5. Verify QEMU Guest Agent, DNS SRV, `dcdiag`, `repadmin`, DHCP where enabled, every selected domain join, SMB ACL/encryption, IIS health, LAPS, effective baseline/GPO, WEF ingestion, Defender, event-log sizing, and firewall isolation.
   Exercise deny and allow transitions for camera, USB storage, and wallpaper on a test user/workstation. Retain `Test-LabAccessControl.ps1` JSON for both states, plus `gpresult` evidence, after the required restart or sign-out.
   Enroll one Windows device that is not in the canonical VM inventory, verify its OU placement and effective background-refresh policy with `Test-LabGroupPolicyRefresh.ps1`, rerun enrollment as a no-op, then disenroll it and verify the intended AD object disposition.
   Publish a package-aware printer, prove discovery from two endpoints, exercise print/deny/admin transitions, and verify that an unapproved print server is rejected. Exercise file-share read/change/deny/remove states and retain effective SMB signing, encryption, share ACL, and NTFS ACL evidence.
   Run `Invoke-LabWindowsActivation.ps1 -Action Activate` for the selected profile, prove every selected server is licensed, prove every selected client reports exactly Windows 11 Education and is licensed, and retain only the redacted JSON status report. Confirm that no complete product key exists in the template, Cloud-Init snippets, logs, reports, or Git history.
6. Interrupt a deployment and successfully resume it.
7. Complete a file restore, isolated System State recovery procedure, retention check, and owned-only teardown.

## Proxmox 9.2 full-profile gate

Deploy each full 30-VM profile individually. Olympus additionally requires isolated network proof, approved data-share ACLs, pinned toolchain checks, its health endpoint, and GPU validation only when passthrough is enabled.

## Labels

- Add `validated-pve-9.2` only after the 9.2 gate passes.
- Add `validated-pve-8.4` only after the 8.4 core gate passes.
- Record PVE build, Windows media hashes/builds, template IDs, definition commit, site mapping digest, timestamps, measured durations, failures, remediations, and evidence locations.

Repository-only checks do not replace the remaining live lab gates above.
