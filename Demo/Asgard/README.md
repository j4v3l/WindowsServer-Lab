# Asgard Technologies

Asgard is the conventional enterprise scenario. Its canonical definition is [`LabConfig/demos/asgard.json`](../../LabConfig/demos/asgard.json).

- Default domain: `ad.asgard.test`
- Legacy opt-in: `asgard.local`
- Smoke: 5 servers and 1 test client (6 VMs)
- Core: 5 servers and 2 clients (7 VMs)
- Full: 5 servers and 25 clients (30 VMs)
- Default address space: `10.10.0.0/16`, split into production, management, client, and DMZ networks

The profile provides redundant AD DS/DNS, departmental users and groups, file services, IIS health output, event collection, role-aware security baselines, Windows LAPS, backup operations, and evidence-based validation.

Use the [Asgard quick start](Guides/QUICK_START_ASGARD.md). For the more specialized AI/ML scenario, see [Olympus](../Olympus/README.md).

Historical v1 guides may use `.local`, fixed credentials, or manual commands. They are reference material only; v2 commands and canonical JSON take precedence.
