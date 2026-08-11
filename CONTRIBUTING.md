# Contributing

Windows Server Lab v2 is a production-like lab framework. Contributions must preserve plan-first behavior, ownership safety, secret hygiene, deterministic inventories, and honest validation claims.

## Local checks

On Linux or macOS with Bash and `jq`:

```bash
Tests/Shell/test-config.sh
shellcheck Tools/Proxmox/*.sh Tools/Proxmox/lib/*.sh Tests/Shell/*.sh
```

With PowerShell 7, Pester 5.7.1, and PSScriptAnalyzer 1.24.0:

```powershell
Invoke-ScriptAnalyzer -Path Scripts/WindowsServerLab -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester Tests/PowerShell
```

CI also parses every PowerShell file with Windows PowerShell 5.1, validates JSON Schema, checks Packer syntax, scans Markdown links and secrets, and smoke-tests release packaging.

## Change rules

- Treat `LabConfig/demos/*.json` as canonical. If an inventory changes, update schema, resource totals, tests, and generated documentation together.
- Keep host commands dry-run by default. Mutations require `--apply`; destructive work requires exact target confirmation and ownership checks.
- Never add passwords, API tokens, private keys, offline-domain-join blobs, retained Cloud-Init secrets, or real recovery data.
- Guest scripts must use strict mode, terminating errors, structured evidence, useful exit codes, parameter validation, idempotent reads before writes, and `SupportsShouldProcess` for state changes.
- Do not count a setting as applied until it is read back from the resulting GPO, local policy, or effective configuration.
- Use Windows PowerShell 5.1-compatible syntax in guest paths. PowerShell 7-only tooling must be clearly isolated.
- Do not add a Proxmox compatibility label without the matching [live certification gate](docs/LIVE_CERTIFICATION.md).

## Pull requests

Describe the affected demo/profile, security impact, plan/apply behavior, tests run, and any live evidence. Link related issues and call out remaining external prerequisites. Keep unrelated cleanup out of the change.

By contributing, you agree that your work is licensed under the repository's [MIT License](LICENSE).
