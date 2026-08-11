#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

operator_file=""
site_file=""
demo=""
profile="smoke"

while (($#)); do
  case "$1" in
    --operator) operator_file="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$operator_file" && -n "$site_file" && -n "$demo" ]] || wslab_die "Usage: $0 --operator <json> --site <json> --demo <asgard|olympus> [--profile <smoke|core|full>]"
wslab_require_command jq
wslab_require_command ssh
operator_file="$(wslab_realpath "$operator_file")"
site_file="$(wslab_realpath "$site_file")"
[[ -r "$operator_file" ]] || wslab_die "Operator configuration is not readable: $operator_file"
wslab_validate_inputs "$demo" "$profile" "$site_file"

host="$(jq -r '.proxmoxHost' "$operator_file")"
node="$(jq -r '.proxmoxNode' "$operator_file")"
ssh_user="$(jq -r '.sshUser' "$operator_file")"
private_key="$(jq -r '.sshPrivateKeyPath' "$operator_file")"
[[ -r "$private_key" ]] || wslab_die "SSH private key is not readable: $private_key"
[[ "$node" == "$(jq -r '.proxmox.node' "$site_file")" ]] || wslab_die "Operator node and site node do not match"

ssh_options=(-n -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "$private_key")
remote=(ssh "${ssh_options[@]}" "${ssh_user}@${host}")
remote_node="$("${remote[@]}" hostname -s)"
[[ "$remote_node" == "$node" ]] || wslab_die "Connected to $remote_node but configuration targets $node"

version="$("${remote[@]}" pveversion | sed -E 's#^[^/]+/([0-9]+\.[0-9]+).*#\1#')"
pve_version_full="$("${remote[@]}" pveversion | head -n 1)"
automation_sha256="$(wslab_template_automation_sha256)"
case "$version" in 8.[4-9]*|9.*) ;; *) wslab_die "Proxmox VE 8.4 or newer is required; found $version" ;; esac

status_json="$("${remote[@]}" pvesh get "/nodes/$node/status" --output-format json)"
storage_json="$("${remote[@]}" pvesh get "/nodes/$node/storage" --output-format json)"
resources_json="$("${remote[@]}" pvesh get /cluster/resources --type vm --output-format json)"
definition_file="$(wslab_definition_path "$demo")"
required_vcpus="$(jq -r --arg profile "$profile" '.resourceLimits[$profile].maximumVcpus' "$definition_file")"
required_memory="$(jq -r --arg profile "$profile" '.resourceLimits[$profile].maximumMemoryMB' "$definition_file")"
required_storage="$(jq -r --arg profile "$profile" '.resourceLimits[$profile].maximumStorageGB' "$definition_file")"
reserve_memory="$(jq -r '.capacity.reserveMemoryMB // 4096' "$site_file")"
host_cpus="$(jq -r '.cpuinfo.cpus' <<<"$status_json")"
available_memory="$(jq -r '.memory.available / 1048576 | floor' <<<"$status_json")"
vm_storage="$(jq -r '.proxmox.vmStorage' "$site_file")"
available_storage="$(jq -r --arg storage "$vm_storage" '[.[] | select(.storage == $storage) | (.avail / 1073741824 | floor)] | first // 0' <<<"$storage_json")"

failures=0
check() {
  local name="$1" passed="$2" evidence="$3"
  if [[ "$passed" == "true" ]]; then
    wslab_log PASS "$name: $evidence"
  else
    wslab_log FAIL "$name: $evidence"
    ((failures += 1))
  fi
}

sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi
}

check pve-version true "$version on $node"
check cpu-budget "$([[ "$required_vcpus" -le "$host_cpus" ]] && printf true || printf false)" "$required_vcpus requested vCPU / $host_cpus host threads"
check memory-budget "$([[ $((required_memory + reserve_memory)) -le "$available_memory" ]] && printf true || printf false)" "$required_memory MB lab + $reserve_memory MB reserve / $available_memory MB currently available"
check storage-budget "$([[ "$required_storage" -le "$available_storage" ]] && printf true || printf false)" "$required_storage GB thin-provisioned / $available_storage GB currently available on $vm_storage"

for storage_role in isoStorage snippetStorage backupStorage; do
  storage_name="$(jq -r --arg role "$storage_role" '.proxmox[$role]' "$site_file")"
  storage_config="$("${remote[@]}" pvesh get "/storage/$storage_name" --output-format json 2>/dev/null || true)"
  case "$storage_role" in isoStorage) required_content=iso ;; snippetStorage) required_content=snippets ;; backupStorage) required_content=backup ;; esac
  storage_type="$(jq -r '.type // empty' <<<"$storage_config")"
  type_ok="true"
  [[ "$storage_role" != "isoStorage" && "$storage_role" != "snippetStorage" ]] || [[ "$storage_type" == "dir" ]] || type_ok="false"
  if [[ -n "$storage_config" && "$type_ok" == "true" ]] && jq -e --arg content "$required_content" '(.content | split(",") | index($content)) != null' <<<"$storage_config" >/dev/null; then
    check "storage-$storage_role" true "$storage_name supports $required_content"
  else
    check "storage-$storage_role" false "$storage_name is absent, lacks $required_content, or is not directory-backed where required"
  fi
done

while IFS= read -r bridge; do
  if "${remote[@]}" test -d "/sys/class/net/$bridge"; then
    if jq -e --arg bridge "$bridge" 'any(.hostNetworking.bridges[]; .name == $bridge)' "$site_file" >/dev/null; then
      uplink="$(jq -r --arg bridge "$bridge" '.hostNetworking.bridges[] | select(.name == $bridge) | .uplink' "$site_file")"
      vlan_filtering="$("${remote[@]}" cat "/sys/class/net/$bridge/bridge/vlan_filtering" 2>/dev/null || printf 0)"
      address_count="$("${remote[@]}" ip -4 -o address show dev "$bridge" | wc -l | tr -d ' ')"
      default_route_count="$("${remote[@]}" ip -4 route show default dev "$bridge" | wc -l | tr -d ' ')"
      carrier="$("${remote[@]}" cat "/sys/class/net/$uplink/carrier" 2>/dev/null || printf 0)"
      bridge_state="$vlan_filtering|$address_count|$default_route_count|$carrier"
      if [[ "$bridge_state" == "1|0|0|1" ]]; then check "bridge-$bridge" true "VLAN-aware, unnumbered, no default route, uplink carrier present"; else check "bridge-$bridge" false "unsafe state $bridge_state (expected 1|0|0|1)"; fi
    else
      check "bridge-$bridge" true present
    fi
  else
    check "bridge-$bridge" false missing
  fi
done < <(jq -r --arg demo "$demo" '.networkMappings[$demo][].bridge' "$site_file" | sort -u)

for command in jq xorriso packer; do
  if "${remote[@]}" command -v "$command" >/dev/null 2>&1; then check "host-command-$command" true present; else check "host-command-$command" false missing; fi
done
if packer_output="$("${remote[@]}" packer version 2>/dev/null)"; then
  packer_version="$(sed -nE 's/^Packer v([0-9]+\.[0-9]+).*/\1/p' <<<"$packer_output" | head -1)"
  packer_major="${packer_version%%.*}"
  packer_minor="${packer_version#*.}"
  if [[ -n "$packer_version" ]] && ((packer_major > 1 || (packer_major == 1 && packer_minor >= 10))); then
    check packer-version true "$packer_version"
  else
    check packer-version false "Packer 1.10 or newer is required"
  fi
fi

for key_type in sshPublicKeyFile sshPrivateKeyFile; do
  key_path="$(jq -r --arg key "$key_type" '.guestAccess[$key]' "$site_file")"
  if "${remote[@]}" test -r "$key_path"; then check "guest-access-$key_type" true "$key_path"; else check "guest-access-$key_type" false "$key_path is missing"; fi
done

for media_name in server2025 windows11; do
  volume="$(jq -r --arg media "$media_name" '.media[$media].volume' "$operator_file")"
  expected_hash="$(jq -r --arg media "$media_name" '.media[$media].sha256' "$operator_file")"
  if media_path="$("${remote[@]}" pvesm path "$volume" 2>/dev/null)" && actual_hash="$("${remote[@]}" sha256sum "$media_path" | awk '{print $1}')" && [[ "$actual_hash" == "$expected_hash" ]]; then
    check "media-$media_name" true "$volume checksum verified"
  else
    check "media-$media_name" false "$volume is absent or its checksum differs"
  fi
done

virtio_volume="$(jq -r '.proxmox.virtioIso' "$site_file")"
virtio_expected_hash="$(jq -r '.proxmox.virtioIsoSha256' "$site_file")"
if virtio_path="$("${remote[@]}" pvesm path "$virtio_volume" 2>/dev/null)" && virtio_actual_hash="$("${remote[@]}" sha256sum "$virtio_path" 2>/dev/null | awk '{print $1}')" && [[ "$virtio_actual_hash" == "$virtio_expected_hash" ]]; then
  check virtio-media true "$virtio_volume checksum verified"
else
  check virtio-media false "$virtio_volume is absent or its checksum differs"
fi

while IFS=$'\t' read -r template_os template_id; do
  template_config="$("${remote[@]}" qm config "$template_id" 2>/dev/null || true)"
  if ! grep -q '^template: 1$' <<<"$template_config"; then
    check "template-$template_id" false "$template_os is not built"
    continue
  fi
  certification_file="$(wslab_template_certification_file "$site_file" "$template_os" "$template_id")"
  build_receipt_file="$(wslab_report_directory "$site_file")/template-builds/template-${template_os}-${template_id}.json"
  certification_json="$("${remote[@]}" cat "$certification_file" 2>/dev/null || true)"
  build_receipt_json="$("${remote[@]}" cat "$build_receipt_file" 2>/dev/null || true)"
  build_automation_sha256="$(jq -r '.automationSha256 // empty' <<<"$build_receipt_json")"
  template_config_sha256="$(sed '/^digest:/d' <<<"$template_config" | LC_ALL=C sort | sha256_stream)"
  if jq -e \
    --arg os "$template_os" \
    --argjson templateId "$template_id" \
    --arg configSha256 "$template_config_sha256" \
    --arg pveVersion "$pve_version_full" \
    --arg buildAutomationSha256 "$build_automation_sha256" \
    --arg automationSha256 "$automation_sha256" '
      .status == "passed" and
      .template.os == $os and
      .template.id == $templateId and
      .template.configSha256 == $configSha256 and
      .template.pveVersion == $pveVersion and
      ($buildAutomationSha256 == "" or
        (.template.automationSha256 == $buildAutomationSha256 and
         $buildAutomationSha256 == $automationSha256)) and
      (.canaries | length == 2) and all(.canaries[]; .status == "passed")
    ' >/dev/null 2>&1 <<<"$certification_json"; then
    check "template-$template_id" true "$template_os is built and certified"
  elif [[ -z "$certification_json" ]]; then
    if [[ -n "$build_receipt_json" ]]; then
      check "template-$template_id" false "$template_os is built but uncertified"
    else
      check "template-$template_id" false "$template_os exists without a matching build receipt and is uncertified"
    fi
  else
    check "template-$template_id" false "$template_os certification is failed or stale"
  fi
done < <(jq -r '.proxmox.templates | to_entries[] | select(.key == "server-2025" or .key == "windows-11") | [.key, .value] | @tsv' "$site_file")

certification_vm_id="$(jq -r '.templateCertification.vmId' "$site_file")"
if jq -e --argjson id "$certification_vm_id" '[.[] | select(.vmid == $id)] | length == 0' >/dev/null <<<"$resources_json"; then
  check certification-vmid true "$certification_vm_id is available"
else
  check certification-vmid false "$certification_vm_id is occupied"
fi

stale_canaries="$(jq '[.[] | select(((.tags // "") | split(";") | index("wslab-certification")) != null)] | length' <<<"$resources_json")"
check stale-certification-vms "$([[ "$stale_canaries" -eq 0 ]] && printf true || printf false)" "$stale_canaries certification VM resources remain"
stale_tokens="$("${remote[@]}" pveum user token list root@pam --output-format json 2>/dev/null | jq '[.[] | select((.tokenid // "") | startswith("wslab-packer-"))] | length' 2>/dev/null || printf 0)"
check stale-packer-tokens "$([[ "$stale_tokens" -eq 0 ]] && printf true || printf false)" "$stale_tokens temporary Packer tokens remain"
packer_processes="$("${remote[@]}" sh -c 'ps -eo args= | grep -c "[p]acker build"' || true)"
check stale-packer-processes "$([[ "${packer_processes:-0}" -eq 0 ]] && printf true || printf false)" "${packer_processes:-0} Packer build processes remain"
iso_storage="$(jq -r '.proxmox.isoStorage' "$site_file")"
iso_storage_path="$("${remote[@]}" pvesh get "/storage/$iso_storage" --output-format json 2>/dev/null | jq -r '.path // empty')"
stale_answer_media=0
if [[ -n "$iso_storage_path" ]]; then
  stale_answer_media="$(
    "${remote[@]}" find "$iso_storage_path/template/iso" -maxdepth 1 -type f -print 2>/dev/null |
      awk '/wslab-(answer|install)-.*[.]iso$/ { count++ } END { print count + 0 }'
  )"
fi
check stale-answer-media "$([[ "$stale_answer_media" -eq 0 ]] && printf true || printf false)" "$stale_answer_media temporary answer ISOs remain"

while IFS=$'\t' read -r vmid vm_name; do
  conflict="$(jq -r --argjson id "$vmid" --arg name "$vm_name" '[.[] | select(.vmid == $id and ((.name // "") != $name or ((.tags // "") | split(";") | index("wslab") | not)))] | length' <<<"$resources_json")"
  check "vmid-$vmid" "$([[ "$conflict" -eq 0 ]] && printf true || printf false)" "$vm_name has no unrelated cluster-wide ID conflict"
done < <(wslab_profile_vms "$definition_file" "$profile" | jq -r '[.id, .name] | @tsv')

((failures == 0)) || wslab_die "$failures remote-host preflight checks failed"
wslab_log PASS "$demo/$profile remote host preflight passed"
