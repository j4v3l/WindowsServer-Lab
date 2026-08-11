# Asgard v2 topology

Generated from `LabConfig/demos/asgard.json`. Site bridges and VLAN tags come from operator-local `LabConfig/site.json`; the defaults below are logical networks only.

```mermaid
flowchart LR
  P["VLAN 90 servers 192.168.90.0/24 via vmbr1/nic1"] --- DC1["ODIN-DC01 .10"]
  P --- DC2["FRIGG-DC02"]
  P --- FS["HEIMDALL-FS01"]
  P --- WEB["BALDER-WEB01"]
  P --- SEC["VIDAR-SEC01"]
  M["management network (core/full: site must supply)"] --- DC1
  M --- DC2
  M --- FS
  M --- SEC
  D["DMZ (core/full: site must supply)"] --- WEB
  C["VLAN 100 clients 192.168.100.0/24 via vmbr1/nic1"] --- CORE["ODIN-WS01 .10 / 2 core / 25 full clients"]
```

`vmbr1` has no host address or gateway and carries only tagged VLANs 90 and 100. `vmbr0` keeps Proxmox management. Only one NIC per VM has a default gateway. Site firewalls must permit required client-to-DC AD/DNS traffic and enforce all other desired inter-VLAN flows; bridge/VLAN attachment alone is not proof of isolation.
