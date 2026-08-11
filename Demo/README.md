# Windows Server Lab demos

The demos are data-driven scenarios backed by `LabConfig/demos`. Their PowerShell deployment entry points are retained only as v1 compatibility shims; v2 deployment runs from the Proxmox host.

| Demo | Core | Full | Default domain | Networks |
|---|---:|---:|---|---|
| [Asgard](Asgard/README.md) | 7 | 30 | `ad.asgard.test` | production, management, client, DMZ |
| [Olympus](Olympus/README.md) | 7 | 30 | `ad.olympus.test` | production, management, client, DMZ, isolated AI/ML |

Start with the [execution-context guide](../docs/EXECUTION_CONTEXT.md), then follow the scenario quick start:

- [Asgard quick start](Asgard/Guides/QUICK_START_ASGARD.md)
- [Olympus quick start](Olympus/Guides/QUICK_START_OLYMPUS.md)

Neither scenario is “validated” solely because static CI passes. The applicable [live certification gate](../docs/LIVE_CERTIFICATION.md) must also pass.
