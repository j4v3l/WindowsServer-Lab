#!/usr/bin/env bash

set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
TEMP_DIR="$(mktemp -d)"
cleanup() {
  case "$TEMP_DIR" in
    /tmp/*|/var/folders/*) rm -rf -- "$TEMP_DIR" ;;
    *) printf 'Refusing to remove unexpected temporary path: %s\n' "$TEMP_DIR" >&2 ;;
  esac
}
trap cleanup EXIT

mkdir -p "$TEMP_DIR/bin" "$TEMP_DIR/reports/template-certifications" "$TEMP_DIR/reports/template-builds"
cp "$REPO_ROOT/LabConfig/site.example.json" "$TEMP_DIR/site.json"
jq --arg reports "$TEMP_DIR/reports" '.paths.reportDirectory = $reports' "$TEMP_DIR/site.json" >"$TEMP_DIR/site.updated.json"
mv "$TEMP_DIR/site.updated.json" "$TEMP_DIR/site.json"

# The mock script expressions must be evaluated by the generated script.
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' \
  'if [[ "${1:-}" == "config" ]]; then' \
  '  printf "%s\n" "description: test-template" "name: wslab-server-2025" "scsi0: local-lvm:base-9000-disk-0,size=64G" "template: 1"' \
  '  [[ -z "${MOCK_CONFIG_DRIFT:-}" ]] || printf "%s\n" "memory: 8192"' \
  'fi' >"$TEMP_DIR/bin/qm"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "pve-manager/9.2.3/test"' >"$TEMP_DIR/bin/pveversion"
chmod 0755 "$TEMP_DIR/bin/qm" "$TEMP_DIR/bin/pveversion"
export PATH="$TEMP_DIR/bin:$PATH"

# shellcheck source=Tools/Proxmox/lib/common.sh
source "$REPO_ROOT/Tools/Proxmox/lib/common.sh"
template_hash="$(wslab_template_config_sha256 9000)"
automation_hash="$(wslab_template_automation_sha256)"
input_hash="$(wslab_template_input_sha256 "$TEMP_DIR/site.json" server-2025)"
evidence_file="$(wslab_template_certification_file "$TEMP_DIR/site.json" server-2025 9000)"
jq -n \
  --arg configHash "$template_hash" \
  --arg automationHash "$automation_hash" \
  '{
    schemaVersion:1,
    status:"passed",
    timestamp:"2026-01-01T00:00:00Z",
    template:{id:9000,os:"server-2025",node:"pve01",pveVersion:"pve-manager/9.2.3/test",configSha256:$configHash,automationSha256:$automationHash,buildRunId:"test",sources:{windowsIsoSha256:("a"*64),virtioIsoSha256:("b"*64)},payloads:{cloudbaseInitSha256:("c"*64),microsoftOsConfigSha256:("e"*64),qemuGuestAgentSha256:("d"*64)}},
    canaries:[
      {sequence:1,vmId:9090,hostname:"WSLAB-S25-A",status:"passed",machineSid:"S-1-5-21-1-2-3",machineGuid:"11111111-1111-1111-1111-111111111111",checks:{all:true}},
      {sequence:2,vmId:9090,hostname:"WSLAB-S25-B",status:"passed",machineSid:"S-1-5-21-4-5-6",machineGuid:"22222222-2222-2222-2222-222222222222",checks:{all:true}}
    ]
  }' >"$evidence_file"
jq -n --arg automationHash "$automation_hash" --arg inputHash "$input_hash" '{schemaVersion:1,automationSha256:$automationHash,inputSha256:$inputHash}' >"$TEMP_DIR/reports/template-builds/template-server-2025-9000.json"

wslab_require_template_certification "$TEMP_DIR/site.json" server-2025 9000

jq '.automationSha256 = ("e"*64)' "$TEMP_DIR/reports/template-builds/template-server-2025-9000.json" >"$TEMP_DIR/drifted-build.json"
mv "$TEMP_DIR/drifted-build.json" "$TEMP_DIR/reports/template-builds/template-server-2025-9000.json"
if (wslab_require_template_certification "$TEMP_DIR/site.json" server-2025 9000) >/dev/null 2>&1; then
  echo 'Certification evidence remained valid after template automation drift.' >&2
  exit 1
fi
jq -n --arg automationHash "$automation_hash" --arg inputHash "$input_hash" '{schemaVersion:1,automationSha256:$automationHash,inputSha256:$inputHash}' >"$TEMP_DIR/reports/template-builds/template-server-2025-9000.json"

cp "$TEMP_DIR/site.json" "$TEMP_DIR/site.before-media-drift.json"
jq '.media["server-2025"].sha256 = ("f"*64)' "$TEMP_DIR/site.json" >"$TEMP_DIR/site.drifted.json"
mv "$TEMP_DIR/site.drifted.json" "$TEMP_DIR/site.json"
if (wslab_require_template_certification "$TEMP_DIR/site.json" server-2025 9000) >/dev/null 2>&1; then
  echo 'Certification evidence remained valid after Windows media drift.' >&2
  exit 1
fi
mv "$TEMP_DIR/site.before-media-drift.json" "$TEMP_DIR/site.json"

if (export MOCK_CONFIG_DRIFT=1; wslab_require_template_certification "$TEMP_DIR/site.json" server-2025 9000) >/dev/null 2>&1; then
  echo 'Certification evidence remained valid after template configuration drift.' >&2
  exit 1
fi

jq '.status = "failed"' "$evidence_file" >"$TEMP_DIR/failed.json"
mv "$TEMP_DIR/failed.json" "$evidence_file"
if (wslab_require_template_certification "$TEMP_DIR/site.json" server-2025 9000) >/dev/null 2>&1; then
  echo 'Failed certification evidence was accepted.' >&2
  exit 1
fi

if grep -Eq 'qm guest exec.*--output-format' \
  "$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh" \
  "$REPO_ROOT/Tools/Proxmox/Activate-LabGuests.sh"; then
  echo 'PVE 9.2-incompatible qm guest exec output formatting was reintroduced.' >&2
  exit 1
fi

grep -Fq '/proc/uptime' "$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh"
grep -Fq '/proc/uptime' "$REPO_ROOT/Tools/Proxmox/lib/common.sh"
# The PowerShell variable is matched literally.
# shellcheck disable=SC2016
grep -Fq '& $sysprep /generalize /oobe /shutdown' "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq 'waiting for Sysprep-owned shutdown' "$REPO_ROOT/packer/windows/seal-template.ps1"
if grep -Fq 'Stop-Computer' "$REPO_ROOT/packer/windows/seal-template.ps1"; then
  echo 'Template sealing must not force a competing shutdown after Sysprep starts.' >&2
  exit 1
fi
grep -Fq "Get-Volume -FileSystemLabel 'config-2'" "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
grep -Fq "openstack\\latest\\user_data" "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
# The PowerShell variable is matched literally.
# shellcheck disable=SC2016
grep -Fq 'Rename-Computer -NewName $desiredHostname' "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
grep -Fq 'Restart-Computer -Force' "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
grep -Fq 'TotalSeconds -ge 120' "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
grep -Fq 'windows-server-lab-template-reconcile.lock' "$REPO_ROOT/Tools/Terraform/Reconcile-Template.sh"
grep -Fq 'Removing safely identified stale certification canary' "$REPO_ROOT/Tools/Terraform/Reconcile-Template.sh"
grep -Fq 'wslab-certification' "$REPO_ROOT/Tools/Terraform/Reconcile-Template.sh"

echo 'Template certification evidence tests passed.'
