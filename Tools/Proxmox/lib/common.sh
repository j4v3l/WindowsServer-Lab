#!/usr/bin/env bash

set -euo pipefail

WSLAB_TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WSLAB_ROOT="$(cd "$WSLAB_TOOL_DIR/../.." && pwd)"

wslab_log() {
  local level="$1"
  shift
  printf '[%s] %-5s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$level" "$*"
}

wslab_die() {
  wslab_log ERROR "$*" >&2
  exit 1
}

wslab_require_command() {
  command -v "$1" >/dev/null 2>&1 || wslab_die "Required command not found: $1"
}

wslab_realpath() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  else
    local directory
    directory="$(cd "$(dirname "$path")" && pwd)"
    printf '%s/%s\n' "$directory" "$(basename "$path")"
  fi
}

wslab_definition_path() {
  printf '%s/LabConfig/lab.json\n' "$WSLAB_ROOT"
}

wslab_proxmox_node() {
  local site_file="$1"
  local node="${WSLAB_PROXMOX_NODE:-}"
  if [[ -z "$node" ]]; then
    node="$(jq -r '.proxmox.node // empty' "$site_file")"
  fi
  if [[ -z "$node" ]]; then
    node="$(hostname -s)"
  fi
  [[ "$node" =~ ^[A-Za-z0-9._-]+$ ]] || wslab_die 'The Proxmox node must be supplied by Terraform or legacy site configuration'
  printf '%s\n' "$node"
}

wslab_validate_inputs() {
  local site_file
  local definition_file

  if (($# == 1)); then
    site_file="$1"
  else
    wslab_die "wslab_validate_inputs expects <site-file>"
  fi
  [[ -r "$site_file" ]] || wslab_die "Site configuration is not readable: $site_file"

  definition_file="$(wslab_definition_path)"
  [[ -r "$definition_file" ]] || wslab_die "Lab definition is not readable: $definition_file"

  jq -e '.schemaVersion == 3' "$site_file" >/dev/null || wslab_die "Site configuration must use schemaVersion 3"
  jq -e '
    (.hostNetworking.bridge | strings | test("^vmbr[0-9]+$")) and
    (.hostNetworking.uplink | strings | length > 0) and
    (.hostNetworking.sharedManagementBridge | booleans) and
    (if .hostNetworking.sharedManagementBridge then .hostNetworking.bridge == "vmbr0" else .hostNetworking.bridge != "vmbr0" end) and
    (.hostNetworking.allowedVlans == [90, 100]) and
    (.proxmox.templates | keys | sort == ["server-2025", "windows-11"]) and
    ([.proxmox.templates[]] | length == (unique | length))
  ' "$site_file" >/dev/null || wslab_die "Site configuration is missing a valid shared/dedicated VLAN 90/100 bridge or template mapping"
  jq -e '
    (.templateBuildNetwork.bridge | strings | length > 0) and
    (.templateBuildNetwork.address | strings | test("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$")) and
    (.templateBuildNetwork.prefixLength >= 1 and .templateBuildNetwork.prefixLength <= 32) and
    (.templateBuildNetwork.gateway | strings | test("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$")) and
    (.templateBuildNetwork.dnsServers | arrays | length > 0)
  ' "$site_file" >/dev/null || wslab_die "Site configuration is missing a valid templateBuildNetwork block"
  jq -e '
    . as $site |
    (.templateCertification.vmId | numbers) >= 100 and
    (.templateCertification.address | strings | test("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$")) and
    (.templateCertification.timeoutSeconds >= 300 and .templateCertification.timeoutSeconds <= 7200) and
    (.templateCertification.address != .templateBuildNetwork.address) and
    ([.proxmox.templates[]] | index($site.templateCertification.vmId) | not) and
    (.media["server-2025"].volume | strings | length > 0) and
    (.media["server-2025"].sha256 | test("^[A-Fa-f0-9]{64}$")) and
    (.media["windows-11"].volume | strings | length > 0) and
    (.media["windows-11"].sha256 | test("^[A-Fa-f0-9]{64}$"))
  ' "$site_file" >/dev/null || wslab_die "Site configuration is missing a valid, nonconflicting templateCertification block"
  jq -e '.schemaVersion == 3 and .name == "asgard"' "$definition_file" >/dev/null || wslab_die "Invalid lab definition"

  local secret_paths
  secret_paths="$(jq -r '[paths(scalars) as $p | select(($p[-1] | tostring | ascii_downcase) | test("password|secret|credential|token")) | $p | join(".")] | .[]?' "$site_file" "$definition_file")"
  [[ -z "$secret_paths" ]] || wslab_die "Secrets are forbidden in lab/site JSON. Disallowed fields: $secret_paths"

  local actual_count unique_ids unique_names unique_ips
  actual_count="$(jq '.virtualMachines | length' "$definition_file")"
  [[ "$actual_count" -ge 6 ]] || wslab_die "The lab must contain the five core server roles and at least one client; found $actual_count VMs"
  unique_ids="$(jq '[.virtualMachines[].id] | unique | length' "$definition_file")"
  unique_names="$(jq '[.virtualMachines[].name] | unique | length' "$definition_file")"
  unique_ips="$(jq '[.virtualMachines[].nics[].ipAddress] | unique | length' "$definition_file")"
  [[ "$unique_ids" -eq "$actual_count" && "$unique_names" -eq "$actual_count" ]] || wslab_die "VM IDs and names must be unique"
  [[ "$unique_ips" -eq "$(jq '[.virtualMachines[].nics[].ipAddress] | length' "$definition_file")" ]] || wslab_die "NIC addresses must be unique"
  jq -e '
    . as $root |
    .networks.windowsServers.cidr == "192.168.90.0/24" and
    .networks.windowsServers.gateway == "192.168.90.1" and
    .networks.windowsServers.vlanId == 90 and
    .networks.windowsClients.cidr == "192.168.100.0/24" and
    .networks.windowsClients.gateway == "192.168.100.1" and
    .networks.windowsClients.vlanId == 100 and
    (.domain.dnsName | endswith(".test")) and
    (.domain.legacyDnsName | endswith(".local")) and
    all(.virtualMachines[]; (.nics | length) == 1) and
    all(.virtualMachines[]; ([.nics[] | select(.defaultGateway == true)] | length) == 1) and
    all($root.virtualMachines[].nics[];
      . as $nic |
      ($root.networks[$nic.network] != null) and
      ($nic.prefixLength == (($root.networks[$nic.network].cidr | split("/")[1]) | tonumber)) and
      ($nic.ipAddress | startswith((($root.networks[$nic.network].cidr | split(".")[0:3]) | join(".")) + "."))
    )
  ' "$definition_file" >/dev/null || wslab_die "The lab has an invalid domain, gateway count, or NIC/network mapping"
  jq -e '
    ([.virtualMachines[] | select(.role == "primary-dc")] | length) == 1 and
    ([.virtualMachines[] | select(.role == "secondary-dc")] | length) == 1 and
    ([.virtualMachines[] | select(.role == "file-server")] | length) == 1 and
    ([.virtualMachines[] | select(.role == "web-server")] | length) == 1 and
    ([.virtualMachines[] | select(.role == "management-server")] | length) == 1 and
    ([.virtualMachines[] | select(.role == "client")] | length) >= 1 and
    all(.virtualMachines[]; if .role == "client" then .os == "windows-11" and .nics[0].network == "windowsClients" else .os == "server-2025" and .nics[0].network == "windowsServers" end)
  ' "$definition_file" >/dev/null || wslab_die "The lab requires one of each core server role, at least one Windows 11 client, and valid OS/network role mappings"
  jq -s -e '
    all(.[];
      ((.dataDisks // []) | map(.slot) | length) == ((.dataDisks // []) | map(.slot) | unique | length) and
      ((.dataDisks // []) | map(.driveLetter) | length) == ((.dataDisks // []) | map(.driveLetter) | unique | length)
    )
  ' < <(wslab_virtual_machines "$definition_file") >/dev/null || wslab_die "The lab has duplicate data-disk slots or drive letters"

  jq -e '.proxmox.templates | [.[]] | length == 2 and (unique | length == 2)' "$site_file" >/dev/null || wslab_die "Template IDs must be unique"
  while IFS= read -r template_id; do
    if jq -e --argjson id "$template_id" '.virtualMachines[] | select(.id == $id)' "$definition_file" >/dev/null; then
      wslab_die "Template ID $template_id collides with a lab VM ID"
    fi
  done < <(jq -r '.proxmox.templates[]' "$site_file")
  certification_vm_id="$(jq -r '.templateCertification.vmId' "$site_file")"
  if jq -e --argjson id "$certification_vm_id" '.virtualMachines[] | select(.id == $id)' "$definition_file" >/dev/null; then
    wslab_die "Certification VM ID $certification_vm_id collides with a lab VM ID"
  fi
  jq -e --slurpfile lab "$definition_file" '
    ($lab[0].networks | [.[] | .vlanId] | sort) as $vlans |
    (.hostNetworking.allowedVlans | sort) == $vlans
  ' "$site_file" >/dev/null || wslab_die "Site bridge VLANs must exactly match the lab networks"
}

wslab_virtual_machines() {
  local definition_file="$1"
  jq -c '[.virtualMachines[] | . + {dataDisks: (.dataDisks // [])}] | sort_by(.bootOrder, .id) | .[]' "$definition_file"
}

wslab_print_command() {
  local item
  printf '  '
  for item in "$@"; do
    printf '%q ' "$item"
  done
  printf '\n'
}

wslab_run() {
  local apply="$1"
  shift
  if [[ "$apply" == "true" ]]; then
    "$@"
  else
    wslab_print_command "$@"
  fi
}

wslab_require_proxmox() {
  wslab_require_command qm
  wslab_require_command pvesh
  wslab_require_command pvesm
  wslab_require_command pveversion

  local version major minor
  version="$(pveversion | sed -E 's#^[^/]+/([0-9]+\.[0-9]+).*#\1#')"
  major="${version%%.*}"
  minor="${version#*.}"
  if ((major != 9 || minor < 2)); then
    wslab_die "Proxmox VE 9.2 or later is required; found $version"
  fi
  wslab_log INFO "Detected Proxmox VE $version"
}

wslab_qm_exists() {
  qm status "$1" >/dev/null 2>&1
}

wslab_qm_name() {
  qm config "$1" 2>/dev/null | awk -F': ' '$1 == "name" {print $2}'
}

wslab_qm_has_tag() {
  local vmid="$1"
  local tag="$2"
  qm config "$vmid" 2>/dev/null | awk -F': ' '$1 == "tags" {print $2}' | tr ';' '\n' | grep -Fxq "$tag"
}

wslab_report_directory() {
  local site_file="$1"
  jq -r '.paths.reportDirectory' "$site_file"
}

wslab_template_certification_directory() {
  local site_file="$1"
  printf '%s/template-certifications\n' "$(wslab_report_directory "$site_file")"
}

wslab_template_certification_file() {
  local site_file="$1"
  local os="$2"
  local template_id="$3"
  printf '%s/template-%s-%s.json\n' "$(wslab_template_certification_directory "$site_file")" "$os" "$template_id"
}

wslab_template_config_sha256() {
  local template_id="$1"
  qm config "$template_id" | sed '/^digest:/d' | LC_ALL=C sort | sha256sum | awk '{print $1}'
}

wslab_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

wslab_sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

wslab_template_automation_sha256() {
  local file file_hash
  local -a fixed_files=(
    Tools/Proxmox/Build-WindowsTemplate.sh
    Tools/Proxmox/Certify-WindowsTemplate.sh
    Tools/Proxmox/Render-WindowsAnswerMedia.py
    Tools/Proxmox/lib/common.sh
    Tools/Terraform/Reconcile-Template.sh
  )
  {
    {
      printf '%s\n' "${fixed_files[@]}"
      find "$WSLAB_ROOT/packer/windows" -type f -print \
        | sed "s#^$WSLAB_ROOT/##"
    } | LC_ALL=C sort -u | while IFS= read -r file; do
      [[ -r "$WSLAB_ROOT/$file" ]] || wslab_die "Template automation file is missing: $file"
      file_hash="$(wslab_sha256_file "$WSLAB_ROOT/$file")"
      printf '%s\0%s\n' "$file" "$file_hash"
    done
  } | wslab_sha256_stream
}

wslab_template_input_sha256() {
  local site_file="$1"
  local os="$2"
  local site_inputs node
  case "$os" in server-2025|windows-11) ;; *) wslab_die "Unsupported template OS: $os" ;; esac
  node="$(wslab_proxmox_node "$site_file")"
  site_inputs="$(jq -cS --arg os "$os" --arg node "$node" '{
    node: $node,
    vmStorage: .proxmox.vmStorage,
    isoStorage: .proxmox.isoStorage,
    virtioIso: .proxmox.virtioIso,
    virtioIsoSha256: .proxmox.virtioIsoSha256,
    templateId: .proxmox.templates[$os],
    windowsMedia: .media[$os],
    buildNetwork: .templateBuildNetwork
  }' "$site_file")"
  printf '%s\0%s\0%s\0%s\n' \
    "$os" \
    "$(wslab_template_automation_sha256)" \
    "$(wslab_sha256_file "$WSLAB_ROOT/LabConfig/build-artifacts.json")" \
    "$site_inputs" | wslab_sha256_stream
}

wslab_require_template_certification() {
  local site_file="$1"
  local os="$2"
  local template_id="$3"
  local evidence_file config_sha256 pve_version build_receipt_file expected_automation_sha256 automation_sha256 expected_input_sha256 input_sha256
  evidence_file="$(wslab_template_certification_file "$site_file" "$os" "$template_id")"
  [[ -r "$evidence_file" ]] || wslab_die "Template $template_id for $os has no certification evidence: $evidence_file"
  config_sha256="$(wslab_template_config_sha256 "$template_id")"
  pve_version="$(pveversion | head -n 1)"
  build_receipt_file="$(wslab_report_directory "$site_file")/template-builds/template-${os}-${template_id}.json"
  expected_automation_sha256="$(jq -r '.automationSha256 // empty' "$build_receipt_file" 2>/dev/null || true)"
  automation_sha256="$(wslab_template_automation_sha256)"
  expected_input_sha256="$(jq -r '.inputSha256 // empty' "$build_receipt_file" 2>/dev/null || true)"
  input_sha256="$(wslab_template_input_sha256 "$site_file" "$os")"
  jq -e \
    --arg os "$os" \
    --argjson templateId "$template_id" \
    --arg configSha256 "$config_sha256" \
    --arg pveVersion "$pve_version" \
    --arg expectedAutomationSha256 "$expected_automation_sha256" \
    --arg automationSha256 "$automation_sha256" \
    --arg expectedInputSha256 "$expected_input_sha256" \
    --arg inputSha256 "$input_sha256" '
      .schemaVersion == 1 and
      .status == "passed" and
      .template.os == $os and
      .template.id == $templateId and
      .template.configSha256 == $configSha256 and
      .template.pveVersion == $pveVersion and
      $expectedAutomationSha256 != "" and
      .template.automationSha256 == $expectedAutomationSha256 and
      $expectedAutomationSha256 == $automationSha256 and
      $expectedInputSha256 != "" and
      $expectedInputSha256 == $inputSha256 and
      (.canaries | length == 2) and
      all(.canaries[]; .status == "passed")
    ' "$evidence_file" >/dev/null || wslab_die "Template $template_id certification is failed, stale, or for a different PVE version"
}

wslab_wait_for_guest_agent() {
  local vmid="$1"
  local timeout_seconds="$2"
  local started elapsed
  started="$(awk '{print int($1)}' /proc/uptime)"
  while ! qm guest cmd "$vmid" ping >/dev/null 2>&1; do
    elapsed="$(( $(awk '{print int($1)}' /proc/uptime) - started ))"
    ((elapsed < timeout_seconds)) || wslab_die "Guest agent for VM $vmid did not become healthy within ${timeout_seconds}s"
    sleep 5
  done
}
