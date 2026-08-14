#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/../Proxmox/lib/common.sh"

emit() {
  jq -n --arg ready "$1" --arg message "$2" '{ready:$ready,message:$message}'
}

query="$(jq -c .)"
mode="$(jq -r '.mode // empty' <<<"$query")"
site_file="$(jq -r '.site_file // empty' <<<"$query")"
lab_file="$(jq -r '.lab_file // empty' <<<"$query")"

if [[ -z "$mode" || -z "$site_file" || -z "$lab_file" ]]; then
  emit false 'Preflight requires mode, site_file, and lab_file.'
  exit 0
fi
if [[ "$(wslab_realpath "$lab_file")" != "$(wslab_definition_path)" ]]; then
  emit false 'Terraform must use the canonical LabConfig/lab.json inventory.'
  exit 0
fi
if ! validation_error="$(wslab_validate_inputs "$site_file" 2>&1)"; then
  emit false "$validation_error"
  exit 0
fi
if [[ "$(id -u)" -ne 0 ]]; then
  emit false 'Terraform must run as root on the targeted Proxmox node.'
  exit 0
fi
if ! proxmox_error="$(wslab_require_proxmox 2>&1)"; then
  emit false "$proxmox_error"
  exit 0
fi

node="$(wslab_proxmox_node "$site_file")"
if [[ "$(hostname -s)" != "$node" ]]; then
  emit false "Site targets node $node, but Terraform is running on $(hostname -s)."
  exit 0
fi

bridge="$(jq -r '.hostNetworking.bridge' "$site_file")"
uplink="$(jq -r '.hostNetworking.uplink' "$site_file")"
shared_management_bridge="$(jq -r '.hostNetworking.sharedManagementBridge' "$site_file")"
management_device="$(ip -4 route show default | awk 'NR == 1 {for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}')"
if [[ -z "$management_device" ]]; then
  emit false 'Unable to determine the Proxmox management/default-route interface.'
  exit 0
fi
if [[ "$shared_management_bridge" == "true" ]]; then
  if [[ "$bridge" != "vmbr0" ]]; then
    emit false "Shared-uplink mode requires existing management bridge vmbr0."
    exit 0
  fi
  if [[ "$bridge" != "$management_device" ]]; then
    emit false "Shared-uplink mode requires existing management bridge vmbr0 to own the default route."
    exit 0
  fi
else
  if [[ "$bridge" == "vmbr0" || "$bridge" == "$management_device" || "$uplink" == "$management_device" ]]; then
    emit false "Dedicated-uplink mode refuses management/default-route interface $management_device."
    exit 0
  fi
fi
if [[ ! -d "/sys/class/net/$uplink" ]]; then
  emit false "Configured lab uplink does not exist: $uplink"
  exit 0
fi
if [[ "$(cat "/sys/class/net/$uplink/carrier" 2>/dev/null || printf 0)" != "1" ]]; then
  emit false "Configured uplink $uplink has no carrier; connect the VLAN 90/100 trunk first."
  exit 0
fi
if [[ -L "/sys/class/net/$uplink/master" ]]; then
  uplink_master="$(basename "$(readlink -f "/sys/class/net/$uplink/master")")"
  if [[ "$uplink_master" != "$bridge" ]]; then
    emit false "Configured uplink $uplink belongs to unrelated interface $uplink_master."
    exit 0
  fi
elif [[ "$shared_management_bridge" == "true" ]]; then
  emit false "Shared management uplink $uplink is not attached to $bridge."
  exit 0
fi

if [[ "$shared_management_bridge" == "true" && ! -d "/sys/class/net/$bridge" ]]; then
  emit false "Shared management bridge $bridge must already exist and remain externally managed."
  exit 0
fi
if [[ -d "/sys/class/net/$bridge" ]]; then
  if [[ "$(cat "/sys/class/net/$bridge/bridge/vlan_filtering" 2>/dev/null || printf 0)" != "1" ]]; then
    emit false "Existing bridge $bridge is not VLAN-aware."
    exit 0
  fi
  bridge_api_json="$(pvesh get "/nodes/$node/network/$bridge" --output-format json 2>/dev/null || true)"
  if [[ "$shared_management_bridge" == "true" ]]; then
    if [[ -z "$(ip -4 -o address show dev "$bridge")" ]] || ! ip -4 route show default dev "$bridge" | grep -q .; then
      emit false "Shared bridge $bridge must retain its management address and default route."
      exit 0
    fi
    if ! jq -e --arg uplink "$uplink" '((.bridge_ports // "") | split(" ") | index($uplink)) != null' >/dev/null 2>&1 <<<"$bridge_api_json"; then
      emit false "Shared bridge $bridge does not own configured management uplink $uplink."
      exit 0
    fi
  else
    if [[ -n "$(ip -4 -o address show dev "$bridge")" ]] || ip -4 route show default dev "$bridge" | grep -q .; then
      emit false "Dedicated bridge $bridge must remain unnumbered and must not own a default route."
      exit 0
    fi
    if ! jq -e '((.comments // .comment // "") | contains("WindowsServerLab Terraform"))' >/dev/null 2>&1 <<<"$bridge_api_json"; then
      emit false "Existing dedicated bridge $bridge does not carry the WindowsServerLab Terraform ownership comment."
      exit 0
    fi
  fi
  if ! command -v bridge >/dev/null 2>&1; then
    emit false 'The iproute2 bridge command is required to validate VLAN membership.'
    exit 0
  fi
  for required_vlan in 90 100; do
    if ! bridge vlan show dev "$uplink" 2>/dev/null | awk -v target="$required_vlan" '
      NR > 1 {
        for (field = 1; field <= NF; field++) {
          if ($field ~ /^[0-9]+$/ && $field == target) found = 1
          if ($field ~ /^[0-9]+-[0-9]+$/) {
            split($field, bounds, "-")
            if (target >= bounds[1] && target <= bounds[2]) found = 1
          }
        }
      }
      END { exit(found ? 0 : 1) }
    '; then
      emit false "Existing bridge uplink $uplink does not allow required VLAN $required_vlan."
      exit 0
    fi
  done
fi

if [[ "$mode" == "foundation" ]]; then
  emit true "Foundation preflight passed for $bridge on $uplink (shared management: $shared_management_bridge)."
  exit 0
fi
if [[ "$mode" != "lab" ]]; then
  emit false "Unsupported preflight mode: $mode"
  exit 0
fi
if [[ ! -d "/sys/class/net/$bridge" ]]; then
  emit false "Lab bridge $bridge is absent; the foundation phase of terraform apply did not complete."
  exit 0
fi

while IFS=$'\t' read -r os template_id; do
  if ! qm status "$template_id" >/dev/null 2>&1 || ! qm config "$template_id" | grep -Eq '^template: 1$'; then
    emit false "Certified template $template_id for $os is absent."
    exit 0
  fi
  if ! certification_error="$(wslab_require_template_certification "$site_file" "$os" "$template_id" 2>&1)"; then
    emit false "$certification_error"
    exit 0
  fi
done < <(jq -r '.proxmox.templates | to_entries[] | [.key, .value] | @tsv' "$site_file")

required_vcpus="$(jq '[.virtualMachines[].cores] | add' "$lab_file")"
required_memory_mb=0
required_storage_gb=0
while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  target_memory="$(jq -r '.memoryMB' <<<"$vm")"
  target_storage="$(jq '[.diskGB, ((.dataDisks // []) | map(.sizeGB) | add // 0)] | add' <<<"$vm")"
  if ! wslab_qm_exists "$vmid"; then
    ((required_memory_mb += target_memory))
    ((required_storage_gb += target_storage))
    continue
  fi
  if [[ "$(wslab_qm_name "$vmid")" != "$name" ]] || ! wslab_qm_has_tag "$vmid" wslab || ! wslab_qm_has_tag "$vmid" terraform; then
    emit false "VM ID $vmid is occupied by an object not owned by this Terraform lab."
    exit 0
  fi
done < <(wslab_virtual_machines "$lab_file")

node_status="$(pvesh get "/nodes/$node/status" --output-format json)"
available_memory_mb="$(jq '.memory.available / 1048576 | floor' <<<"$node_status")"
host_threads="$(jq '.cpuinfo.cpus' <<<"$node_status")"
reserve_memory_mb="$(jq -r '.capacity.reserveMemoryMB' "$site_file")"
vm_storage="$(jq -r '.proxmox.vmStorage' "$site_file")"
available_storage_gb="$(pvesh get "/nodes/$node/storage" --output-format json | jq --arg storage "$vm_storage" '[.[] | select(.storage == $storage) | (.avail / 1073741824 | floor)] | first // 0')"
if ((required_memory_mb + reserve_memory_mb > available_memory_mb)); then
  emit false "Lab needs ${required_memory_mb} MB plus ${reserve_memory_mb} MB reserve; only ${available_memory_mb} MB is available."
  exit 0
fi
if ((required_vcpus > host_threads)); then
  emit false "Lab needs $required_vcpus vCPU, exceeding the node's $host_threads hardware threads."
  exit 0
fi
if ((required_storage_gb > available_storage_gb)); then
  emit false "Lab needs ${required_storage_gb} GB of additional storage; only ${available_storage_gb} GB is available in $vm_storage."
  exit 0
fi

mapfile -t selected_ids < <(jq -r '.virtualMachines[].id' "$lab_file")
mapfile -t selected_names < <(jq -r '.virtualMachines[].name' "$lab_file")
mapfile -t selected_ips < <(jq -r '.virtualMachines[].nics[].ipAddress' "$lab_file")
while IFS= read -r cluster_vm; do
  other_id="$(jq -r '.vmid' <<<"$cluster_vm")"
  if printf '%s\n' "${selected_ids[@]}" | grep -Fxq "$other_id"; then
    continue
  fi
  other_name="$(jq -r '.name // empty' <<<"$cluster_vm")"
  if [[ -n "$other_name" ]] && printf '%s\n' "${selected_names[@]}" | grep -Fxq "$other_name"; then
    emit false "Requested VM name $other_name is already used by unrelated VM ID $other_id."
    exit 0
  fi
  other_config="$(qm config "$other_id" 2>/dev/null || true)"
  for requested_ip in "${selected_ips[@]}"; do
    if grep -Fq "ip=${requested_ip}/" <<<"$other_config"; then
      emit false "Requested IP $requested_ip is configured on unrelated VM ID $other_id."
      exit 0
    fi
  done
done < <(pvesh get /cluster/resources --type vm --output-format json | jq -c '.[] | select(.type == "qemu")')

emit true 'Lab preflight passed: bridge, templates, ownership, capacity, names, and addresses are ready.'
