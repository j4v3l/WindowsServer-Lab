# Olympus Systems

Olympus extends the base enterprise lab with an opt-in, testable AI/ML feature pack. Its canonical definition is [`LabConfig/demos/olympus.json`](../../LabConfig/demos/olympus.json).

- Default domain: `ad.olympus.test`
- Legacy opt-in: `olympus.local`
- Smoke: 5 servers and 1 test client (6 VMs)
- Core: 5 servers and 2 clients (7 VMs)
- Full: 5 servers and 25 clients (30 VMs)
- Default address space: `10.20.0.0/16`, including isolated `10.20.60.0/24` AI/ML clients

AI/ML packages must come from a schema-validated manifest with pinned SHA-256 hashes. The installer creates a local JSON health report and endpoint; validation fails if the feature is claimed but unhealthy. GPU passthrough and cloud integration remain false by default and are never inferred from marketing labels.

Use the [Olympus quick start](Guides/QUICK_START_OLYMPUS.md). See [Asgard](../Asgard/README.md) for the conventional scenario.

Historical v1 guides may use `.local`, fixed credentials, or manual commands. They are reference material only; v2 commands and canonical JSON take precedence.
