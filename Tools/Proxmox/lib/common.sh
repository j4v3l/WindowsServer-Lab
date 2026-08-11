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
  local demo="$1"
  printf '%s/LabConfig/demos/%s.json\n' "$WSLAB_ROOT" "$demo"
}

wslab_validate_inputs() {
  local demo="$1"
  local profile="$2"
  local site_file="$3"
  local definition_file

  [[ "$demo" == "asgard" || "$demo" == "olympus" ]] || wslab_die "Demo must be asgard or olympus"
  [[ "$profile" == "smoke" || "$profile" == "core" || "$profile" == "full" ]] || wslab_die "Profile must be smoke, core, or full"
  [[ -r "$site_file" ]] || wslab_die "Site configuration is not readable: $site_file"

  definition_file="$(wslab_definition_path "$demo")"
  [[ -r "$definition_file" ]] || wslab_die "Demo definition is not readable: $definition_file"

  jq -e '.schemaVersion == 2' "$site_file" >/dev/null || wslab_die "Site configuration must use schemaVersion 2"
  jq -e '
    (.hostNetworking.bridges | arrays | length > 0) and
    ([.hostNetworking.bridges[].name] | length == (unique | length)) and
    ([.hostNetworking.bridges[].uplink] | length == (unique | length)) and
    all(.hostNetworking.bridges[];
      (.name | test("^vmbr[0-9]+$")) and
      (.uplink | strings | length > 0) and
      .vlanAware == true and
      .management == false and
      (.allowedVlans | arrays | length > 0) and
      all(.allowedVlans[]; . >= 1 and . <= 4094)
    )
  ' "$site_file" >/dev/null || wslab_die "Site configuration is missing a safe, non-management hostNetworking bridge"
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
    ([.proxmox.templates[]] | index($site.templateCertification.vmId) | not)
  ' "$site_file" >/dev/null || wslab_die "Site configuration is missing a valid, nonconflicting templateCertification block"
  jq -e --arg demo "$demo" '.schemaVersion == 2 and .demo == $demo' "$definition_file" >/dev/null || wslab_die "Invalid demo definition"

  local secret_paths
  secret_paths="$(jq -r '[paths(scalars) as $p | select(($p[-1] | tostring | ascii_downcase) | test("password|secret|credential|token")) | $p | join(".")] | .[]?' "$site_file" "$definition_file")"
  [[ -z "$secret_paths" ]] || wslab_die "Secrets are forbidden in lab/site JSON. Disallowed fields: $secret_paths"

  local expected_count actual_count
  case "$profile" in
    smoke) expected_count=6 ;;
    core) expected_count=7 ;;
    full) expected_count=30 ;;
  esac
  actual_count="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile))] | length' "$definition_file")"
  [[ "$actual_count" -eq "$expected_count" ]] || wslab_die "$demo/$profile must contain $expected_count VMs; found $actual_count"

  local unique_ids unique_names unique_ips
  unique_ids="$(jq '[.virtualMachines[].id] | unique | length' "$definition_file")"
  unique_names="$(jq '[.virtualMachines[].name] | unique | length' "$definition_file")"
  unique_ips="$(jq '[.virtualMachines[].nics[].ipAddress] | unique | length' "$definition_file")"
  [[ "$unique_ids" -eq 30 && "$unique_names" -eq 30 ]] || wslab_die "VM IDs and names must be unique"
  [[ "$unique_ips" -eq "$(jq '[.virtualMachines[].nics[].ipAddress] | length' "$definition_file")" ]] || wslab_die "NIC addresses must be unique"
  jq -e '
    . as $root |
    (.domain.dnsName | endswith(".test")) and
    (.domain.legacyDnsName | endswith(".local")) and
    all(.virtualMachines[]; ([.nics[] | select(.defaultGateway == true)] | length) == 1) and
    all($root.virtualMachines[].nics[];
      . as $nic |
      ($root.networks[$nic.network] != null) and
      ($nic.prefixLength == (($root.networks[$nic.network].cidr | split("/")[1]) | tonumber)) and
      ($nic.ipAddress | startswith((($root.networks[$nic.network].cidr | split(".")[0:3]) | join(".")) + "."))
    )
  ' "$definition_file" >/dev/null || wslab_die "$demo has an invalid domain, gateway count, or NIC/network mapping"
  jq -e --arg profile "$profile" '
    [.virtualMachines[] | select(.profiles | index($profile))] as $selected |
    ([$selected[] | select(.role == "client" or .role == "aiml-client")] | length) == (if $profile == "smoke" then 1 elif $profile == "core" then 2 else 25 end) and
    ([$selected[] | select(.role != "client" and .role != "aiml-client")] | length) == 5
  ' "$definition_file" >/dev/null || wslab_die "$demo/$profile must contain five servers and the expected client count"
  jq -s -e '([.[].nics[].ipAddress] | length) == ([.[].nics[].ipAddress] | unique | length)' < <(wslab_profile_vms "$definition_file" "$profile") >/dev/null || wslab_die "$demo/$profile resolved NIC addresses must be unique"
  jq -e --slurpfile selected <(wslab_profile_vms "$definition_file" "$profile") '
    . as $root |
    all($selected[].nics[];
      . as $nic |
      ($root.networks[$nic.network] != null) and
      ($nic.prefixLength == (($root.networks[$nic.network].cidr | split("/")[1]) | tonumber)) and
      ($nic.ipAddress | startswith((($root.networks[$nic.network].cidr | split(".")[0:3]) | join(".")) + "."))
    )
  ' "$definition_file" >/dev/null || wslab_die "$demo/$profile has an invalid resolved NIC override"
  jq -s -e '
    all(.[];
      ((.dataDisks // []) | map(.slot) | length) == ((.dataDisks // []) | map(.slot) | unique | length) and
      ((.dataDisks // []) | map(.driveLetter) | length) == ((.dataDisks // []) | map(.driveLetter) | unique | length)
    )
  ' < <(wslab_profile_vms "$definition_file" "$profile") >/dev/null || wslab_die "$demo/$profile has duplicate data-disk slots or drive letters"

  jq -e '.proxmox.templates | [.[]] | length == 3 and (unique | length == 3)' "$site_file" >/dev/null || wslab_die "Template IDs must be unique"
  while IFS= read -r template_id; do
    if jq -e --argjson id "$template_id" '.virtualMachines[] | select(.id == $id)' "$definition_file" >/dev/null; then
      wslab_die "Template ID $template_id collides with a lab VM ID"
    fi
  done < <(jq -r '.proxmox.templates[]' "$site_file")
  certification_vm_id="$(jq -r '.templateCertification.vmId' "$site_file")"
  if jq -e --argjson id "$certification_vm_id" '.virtualMachines[] | select(.id == $id)' "$definition_file" >/dev/null; then
    wslab_die "Certification VM ID $certification_vm_id collides with a lab VM ID"
  fi
  jq -s -e '[.[].networks[].cidr] | length == (unique | length)' "$WSLAB_ROOT/LabConfig/demos/asgard.json" "$WSLAB_ROOT/LabConfig/demos/olympus.json" >/dev/null || wslab_die "Asgard and Olympus logical networks must not overlap"

  local required_vcpus required_memory required_storage capacity_vcpus capacity_memory capacity_storage
  required_vcpus="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile)) | (.profileResourceOverrides[$profile].cores // .cores)] | add' "$definition_file")"
  required_memory="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile)) | (.profileResourceOverrides[$profile].memoryMB // .memoryMB)] | add' "$definition_file")"
  required_storage="$(wslab_profile_vms "$definition_file" "$profile" | jq -s '[.[] | .diskGB + ((.dataDisks // []) | map(.sizeGB) | add // 0)] | add')"
  capacity_vcpus="$(jq -r '.capacity.vcpus' "$site_file")"
  capacity_memory="$(jq -r '.capacity.memoryMB' "$site_file")"
  capacity_storage="$(jq -r '.capacity.storageGB' "$site_file")"
  [[ "$required_vcpus" -le "$capacity_vcpus" ]] || wslab_die "$demo/$profile requires $required_vcpus vCPU but the site declares $capacity_vcpus"
  [[ "$required_memory" -le "$capacity_memory" ]] || wslab_die "$demo/$profile requires $required_memory MB RAM but the site declares $capacity_memory"
  [[ "$required_storage" -le "$capacity_storage" ]] || wslab_die "$demo/$profile requires $required_storage GB storage but the site declares $capacity_storage"

  jq -e --arg profile "$profile" --argjson vms "$actual_count" --argjson vcpus "$required_vcpus" --argjson memory "$required_memory" --argjson storage "$required_storage" '
    .resourceLimits[$profile].maximumVMs == $vms and
    .resourceLimits[$profile].maximumVcpus == $vcpus and
    .resourceLimits[$profile].maximumMemoryMB == $memory and
    .resourceLimits[$profile].maximumStorageGB == $storage
  ' "$definition_file" >/dev/null || wslab_die "$demo/$profile resourceLimits do not match its canonical inventory"

  while IFS= read -r network; do
    if [[ "$demo" == "asgard" && "$profile" != "smoke" ]]; then
      jq -e --arg demo "$demo" --arg network "$network" '.networkMappings[$demo][$network].configured == true' "$site_file" >/dev/null || wslab_die "Asgard $profile is blocked until the site explicitly supplies the $network network mapping"
    fi
    jq -e --arg demo "$demo" --arg network "$network" '
      (.networkMappings[$demo][$network].bridge | strings | length > 0) and
      (.networkMappings[$demo][$network] | has("vlanTag"))
    ' "$site_file" >/dev/null || wslab_die "Missing site network mapping for $demo/$network"
    mapping_bridge="$(jq -r --arg demo "$demo" --arg network "$network" '.networkMappings[$demo][$network].bridge' "$site_file")"
    mapping_vlan="$(jq -r --arg demo "$demo" --arg network "$network" '.networkMappings[$demo][$network].vlanTag' "$site_file")"
    if [[ "$mapping_vlan" -gt 0 ]] && jq -e --arg bridge "$mapping_bridge" 'any(.hostNetworking.bridges[]; .name == $bridge)' "$site_file" >/dev/null; then
      jq -e --arg bridge "$mapping_bridge" --argjson vlan "$mapping_vlan" '
        any(.hostNetworking.bridges[]; .name == $bridge and (.allowedVlans | index($vlan)) != null)
      ' "$site_file" >/dev/null || wslab_die "Mapped VLAN $mapping_vlan for $demo/$network is not allowed on host bridge $mapping_bridge"
    fi
  done < <(wslab_profile_vms "$definition_file" "$profile" | jq -r '.nics[].network' | sort -u)
}

wslab_profile_vms() {
  local definition_file="$1"
  local profile="$2"
  jq -c --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile)) |
    . as $vm | (.profileResourceOverrides[$profile] // {}) as $override |
    . + {
      cores: ($override.cores // $vm.cores),
      memoryMB: ($override.memoryMB // $vm.memoryMB),
      diskGB: ($override.diskGB // $vm.diskGB),
      balloonMinimumMB: ($override.balloonMinimumMB // 2048),
      nics: ($vm.profileNicOverrides[$profile] // $vm.nics),
      dataDisks: ($vm.profileDataDiskOverrides[$profile] // $vm.dataDisks // [])
    }
  ] | sort_by(.bootOrder, .id) | .[]' "$definition_file"
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
  if ((major < 8 || (major == 8 && minor < 4))); then
    wslab_die "Proxmox VE 8.4 or later is required; found $version"
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
  local -a files=(
    Tools/Proxmox/Build-WindowsTemplate.sh
    Tools/Proxmox/Render-WindowsAnswerMedia.py
    packer/windows/Autounattend.xml.pkrtpl
    packer/windows/bootstrap.ps1.pkrtpl
    packer/windows/finalize-template.ps1
    packer/windows/first-boot-cleanup.ps1
    packer/windows/prepare-template.ps1
    packer/windows/seal-template.ps1
    packer/windows/wait-for-template-shutdown.sh
    packer/windows/windows.pkr.hcl
  )
  {
    for file in "${files[@]}"; do
      [[ -r "$WSLAB_ROOT/$file" ]] || wslab_die "Template automation file is missing: $file"
      file_hash="$(wslab_sha256_file "$WSLAB_ROOT/$file")"
      printf '%s\0%s\n' "$file" "$file_hash"
    done
  } | wslab_sha256_stream
}

wslab_require_template_certification() {
  local site_file="$1"
  local os="$2"
  local template_id="$3"
  local evidence_file config_sha256 pve_version build_receipt_file expected_automation_sha256 automation_sha256
  evidence_file="$(wslab_template_certification_file "$site_file" "$os" "$template_id")"
  [[ -r "$evidence_file" ]] || wslab_die "Template $template_id for $os has no certification evidence: $evidence_file"
  config_sha256="$(wslab_template_config_sha256 "$template_id")"
  pve_version="$(pveversion | head -n 1)"
  build_receipt_file="$(wslab_report_directory "$site_file")/template-builds/template-${os}-${template_id}.json"
  expected_automation_sha256="$(jq -r '.automationSha256 // empty' "$build_receipt_file" 2>/dev/null || true)"
  automation_sha256="$(wslab_template_automation_sha256)"
  jq -e \
    --arg os "$os" \
    --argjson templateId "$template_id" \
    --arg configSha256 "$config_sha256" \
    --arg pveVersion "$pve_version" \
    --arg expectedAutomationSha256 "$expected_automation_sha256" \
    --arg automationSha256 "$automation_sha256" '
      .schemaVersion == 1 and
      .status == "passed" and
      .template.os == $os and
      .template.id == $templateId and
      .template.configSha256 == $configSha256 and
      .template.pveVersion == $pveVersion and
      ($expectedAutomationSha256 == "" or
        (.template.automationSha256 == $expectedAutomationSha256 and
         $expectedAutomationSha256 == $automationSha256)) and
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
