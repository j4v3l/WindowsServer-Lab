# Olympus v2 topology

Generated from `LabConfig/demos/olympus.json`. Site bridges and VLAN tags come from operator-local `LabConfig/site.json`; the defaults below are logical networks only.

```mermaid
flowchart LR
  P["production 10.20.10.0/24"] --- DC1["ZEUS-DC01"]
  P --- DC2["HERA-DC02"]
  P --- FS["HERMES-FS01"]
  P --- WEB["APOLLO-WEB01"]
  P --- SEC["ATHENA-SEC01"]
  M["management 10.20.100.0/24"] --- DC1
  M --- DC2
  M --- FS
  M --- SEC
  D["DMZ 10.20.50.0/24"] --- WEB
  C["client 10.20.20.0/24"] --- CLIENTS["20 standard full-profile clients"]
  AI["isolated AI/ML 10.20.60.0/24"] --- AIML["5 pinned-toolchain full-profile clients"]
```

The core profile selects two standard clients and no AI/ML client. Only one NIC per VM has a default gateway. Site firewalls must prove AI/ML and DMZ isolation; VLAN attachment alone is not sufficient.
