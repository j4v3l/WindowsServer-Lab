#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

demo=""
profile=""
site_file=""
apply="false"
legacy_domain="false"
server_os_override=""

usage() {
  printf 'Usage: %s --demo <asgard|olympus> --profile <smoke|core|full> --site <file> [--server-os <server-2025|server-2022>] [--legacy-domain] [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --legacy-domain) legacy_domain="true"; shift ;;
    --server-os) server_os_override="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$demo" && -n "$profile" && -n "$site_file" ]] || { usage >&2; exit 2; }
[[ -z "$server_os_override" || "$server_os_override" == "server-2025" || "$server_os_override" == "server-2022" ]] || wslab_die "--server-os must be server-2025 or server-2022"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$demo" "$profile" "$site_file"
definition_file="$(wslab_definition_path "$demo")"

if [[ "$apply" == "true" ]]; then
  [[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
  wslab_require_proxmox
  public_key_file="$(jq -r '.guestAccess.sshPublicKeyFile' "$site_file")"
  [[ -r "$public_key_file" ]] || wslab_die "Guest SSH public key is not readable: $public_key_file"
fi

node="$(jq -r '.proxmox.node' "$site_file")"
vm_storage="$(jq -r '.proxmox.vmStorage' "$site_file")"
snippet_storage="$(jq -r '.proxmox.snippetStorage' "$site_file")"
guest_user="$(jq -r '.guestAccess.user' "$site_file")"
start_after_deploy="$(jq -r '.features.startAfterDeploy // true' "$site_file")"
secure_boot="$(jq -r '.features.secureBoot // true' "$site_file")"
tpm="$(jq -r '.features.tpm // true' "$site_file")"
guest_agent_timeout="$(jq -r '.features.guestAgentTimeoutSeconds // 900' "$site_file")"
domain_name="$(jq -r ".domain.$([[ "$legacy_domain" == "true" ]] && printf legacyDnsName || printf dnsName)" "$definition_file")"
dns_servers="$(jq -r '.networks.production.dnsServers | join(" ")' "$definition_file")"
report_directory="$(wslab_report_directory "$site_file")"

if [[ "$apply" == "true" ]]; then
  current_node="$(hostname -s)"
  [[ "$node" == "$current_node" ]] || wslab_die "Site targets node $node but this host is $current_node"
  mkdir -p "$report_directory"

  required_vcpus="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile)) | (.profileResourceOverrides[$profile].cores // .cores)] | add' "$definition_file")"
  capacity_memory_mb=0
  capacity_storage_gb=0
  while IFS= read -r capacity_vm; do
    capacity_vmid="$(jq -r '.id' <<<"$capacity_vm")"
    capacity_target_memory="$(jq -r '.memoryMB' <<<"$capacity_vm")"
    capacity_target_disk="$(jq '[.diskGB, ((.dataDisks // []) | map(.sizeGB) | add // 0)] | add' <<<"$capacity_vm")"
    if ! wslab_qm_exists "$capacity_vmid"; then
      ((capacity_memory_mb += capacity_target_memory))
      ((capacity_storage_gb += capacity_target_disk))
      continue
    fi

    # Available host memory already excludes a running VM's current allocation,
    # so an idempotent rerun must reserve only any requested increase. A stopped
    # VM still needs its full target allocation before it can be started.
    capacity_config="$(qm config "$capacity_vmid")"
    capacity_status="$(qm status "$capacity_vmid" | awk '{print $2}')"
    capacity_current_memory="$(sed -n 's/^memory: //p' <<<"$capacity_config")"
    if [[ "$capacity_status" == "running" && "$capacity_current_memory" =~ ^[0-9]+$ ]]; then
      ((capacity_target_memory > capacity_current_memory)) && ((capacity_memory_mb += capacity_target_memory - capacity_current_memory))
    else
      ((capacity_memory_mb += capacity_target_memory))
    fi

    capacity_current_disk="$(sed -nE 's/^scsi[0-9]+:.*size=([0-9]+)G([,].*)?$/\1/p' <<<"$capacity_config" | awk '{sum += $1} END {print sum + 0}')"
    if [[ "$capacity_current_disk" =~ ^[0-9]+$ && "$capacity_target_disk" -gt "$capacity_current_disk" ]]; then
      ((capacity_storage_gb += capacity_target_disk - capacity_current_disk))
    fi
  done < <(wslab_profile_vms "$definition_file" "$profile")
  reserve_memory_mb="$(jq -r '.capacity.reserveMemoryMB // 4096' "$site_file")"
  node_status="$(pvesh get "/nodes/$node/status" --output-format json)"
  host_available_mb="$(jq '.memory.available / 1048576 | floor' <<<"$node_status")"
  host_threads="$(jq '.cpuinfo.cpus' <<<"$node_status")"
  storage_available_gb="$(pvesh get "/nodes/$node/storage" --output-format json | jq --arg storage "$vm_storage" '[.[] | select(.storage == $storage) | (.avail / 1073741824 | floor)] | first // 0')"
  ((capacity_memory_mb + reserve_memory_mb <= host_available_mb)) || wslab_die "$demo/$profile needs ${capacity_memory_mb} MB of additional/start memory plus ${reserve_memory_mb} MB reserve, but $node currently has only ${host_available_mb} MB available"
  ((required_vcpus <= host_threads)) || wslab_die "$demo/$profile needs $required_vcpus vCPU, exceeding the $host_threads hardware threads declared safe for this site"
  running_vcpus="$(pvesh get /cluster/resources --type vm --output-format json | jq '[.[] | select(.type == "qemu" and .status == "running") | (.maxcpu // 0)] | add // 0')"
  if ((running_vcpus + required_vcpus > host_threads)); then
    wslab_log WARN "Running guests plus $demo/$profile request $((running_vcpus + required_vcpus)) vCPU on $host_threads hardware threads"
  fi
  ((running_vcpus + required_vcpus <= host_threads * 2)) || wslab_die "Projected CPU overcommit exceeds the site safety ceiling of 2:1"
  ((capacity_storage_gb <= storage_available_gb)) || wslab_die "$demo/$profile needs ${capacity_storage_gb} GB of additional thin-provisioned storage, but $vm_storage currently has only ${storage_available_gb} GB available"

  mapfile -t selected_ids < <(wslab_profile_vms "$definition_file" "$profile" | jq -r '.id')
  mapfile -t selected_names < <(wslab_profile_vms "$definition_file" "$profile" | jq -r '.name')
  mapfile -t selected_ips < <(wslab_profile_vms "$definition_file" "$profile" | jq -r '.nics[].ipAddress')
  while IFS= read -r cluster_vm; do
    other_id="$(jq -r '.vmid' <<<"$cluster_vm")"
    if printf '%s\n' "${selected_ids[@]}" | grep -Fxq "$other_id"; then continue; fi
    other_name="$(jq -r '.name // empty' <<<"$cluster_vm")"
    if [[ -n "$other_name" ]] && printf '%s\n' "${selected_names[@]}" | grep -Fxq "$other_name"; then
      wslab_die "Requested VM name $other_name is already used by unrelated VM ID $other_id"
    fi
    other_config="$(qm config "$other_id" 2>/dev/null || true)"
    for requested_ip in "${selected_ips[@]}"; do
      if grep -Fq "ip=${requested_ip}/" <<<"$other_config"; then
        wslab_die "Requested IP $requested_ip is already configured on unrelated VM ID $other_id"
      fi
    done
  done < <(pvesh get /cluster/resources --type vm --output-format json | jq -c '.[] | select(.type == "qemu")')
fi

wslab_log INFO "$([[ "$apply" == "true" ]] && printf APPLY || printf PLAN) $demo/$profile on node $node using domain $domain_name"

declare -A checked_templates=()
declare -A checked_bridges=()
created=0
updated=0

while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  role="$(jq -r '.role' <<<"$vm")"
  os="$(jq -r '.os' <<<"$vm")"
  if [[ -n "$server_os_override" && "$os" == server-* ]]; then os="$server_os_override"; fi
  cores="$(jq -r '.cores' <<<"$vm")"
  memory="$(jq -r '.memoryMB' <<<"$vm")"
  balloon_minimum="$(jq -r '.balloonMinimumMB // 2048' <<<"$vm")"
  disk="$(jq -r '.diskGB' <<<"$vm")"
  boot_order="$(jq -r '.bootOrder' <<<"$vm")"
  template_id="$(jq -r --arg os "$os" '.proxmox.templates[$os]' "$site_file")"

  if [[ "$apply" == "true" && -z "${checked_templates[$template_id]:-}" ]]; then
    qm status "$template_id" >/dev/null 2>&1 || wslab_die "Template VM $template_id for $os does not exist"
    qm config "$template_id" | grep -Eq '^template: 1$' || wslab_die "VM $template_id is not a template"
    wslab_require_template_certification "$site_file" "$os" "$template_id"
    checked_templates[$template_id]=1
  fi

  exists="false"
  if [[ "$apply" == "true" ]] && wslab_qm_exists "$vmid"; then
    exists="true"
    existing_name="$(wslab_qm_name "$vmid")"
    [[ "$existing_name" == "$name" ]] || wslab_die "VM ID $vmid belongs to $existing_name, not $name"
    wslab_qm_has_tag "$vmid" "wslab" || wslab_die "Refusing to modify unowned VM $vmid ($name)"
  fi

  wslab_log INFO "$name ($vmid, $role): $([[ "$exists" == "true" ]] && printf reconcile || printf create)"

  if [[ "$exists" == "false" ]]; then
    wslab_run "$apply" qm clone "$template_id" "$vmid" --name "$name" --full 1 --storage "$vm_storage"
    ((created += 1))
  else
    ((updated += 1))
  fi

  while IFS= read -r data_disk; do
    data_slot="$(jq -r '.slot' <<<"$data_disk")"
    data_size="$(jq -r '.sizeGB' <<<"$data_disk")"
    if [[ "$apply" == "true" ]]; then
      existing_data_config="$(qm config "$vmid" | sed -n "s/^${data_slot}: //p")"
      if [[ -z "$existing_data_config" ]]; then
        qm set "$vmid" "--${data_slot}" "${vm_storage}:${data_size},cache=none,discard=on,iothread=1,ssd=1" >/dev/null
      else
        existing_data_size="$(sed -nE 's/^.*size=([0-9]+)G([,].*)?$/\1/p' <<<"$existing_data_config")"
        [[ "$existing_data_size" =~ ^[0-9]+$ ]] || wslab_die "VM $vmid $data_slot is not a managed data disk; refusing to overwrite it"
        if ((existing_data_size < data_size)); then
          qm disk resize "$vmid" "$data_slot" "${data_size}G"
        elif ((existing_data_size > data_size)); then
          wslab_log WARN "$name $data_slot is ${existing_data_size}G, larger than the declared ${data_size}G; data disks are never shrunk automatically"
        fi
      fi
    else
      wslab_print_command qm set "$vmid" "--${data_slot}" "${vm_storage}:${data_size},cache=none,discard=on,iothread=1,ssd=1"
    fi
  done < <(jq -c '.dataDisks[]?' <<<"$vm")

  tags="wslab;${demo};${profile};${role}"
  wslab_run "$apply" qm set "$vmid" --name "$name" --cores "$cores" --memory "$memory" --balloon "$balloon_minimum" --agent "enabled=1,freeze-fs-on-backup=1" --onboot 1 --startup "order=${boot_order},up=30,down=60" --tags "$tags" --scsihw virtio-scsi-single --citype configdrive2

  if [[ "$apply" == "true" ]]; then
    ide2_config="$(qm config "$vmid" | sed -n 's/^ide2: //p')"
    if [[ -n "$ide2_config" && "$ide2_config" != *cloudinit* ]]; then
      wslab_die "VM $vmid already has a non-Cloud-Init ide2 device; refusing to overwrite it"
    fi
    if [[ -z "$ide2_config" ]]; then
      qm set "$vmid" --ide2 "${vm_storage}:cloudinit" >/dev/null
    fi
  else
    wslab_print_command qm set "$vmid" --ide2 "${vm_storage}:cloudinit"
  fi

  # Packer creates 64 GiB server and 80 GiB client template disks. Proxmox
  # rejects a resize to the current size, and it cannot shrink a disk. Inspect
  # the cloned/current disk in apply mode and grow it only when required.
  if [[ "$apply" == "true" ]]; then
    wslab_require_command numfmt
    current_disk_size="$(qm config "$vmid" | sed -nE 's/^scsi0:.*size=([^,]+).*/\1/p')"
    [[ -n "$current_disk_size" ]] || wslab_die "Unable to determine scsi0 size for VM $vmid"
    current_disk_bytes="$(numfmt --from=iec "${current_disk_size^^}")"
    target_disk_bytes="$((disk * 1073741824))"
    if ((current_disk_bytes < target_disk_bytes)); then
      qm disk resize "$vmid" scsi0 "${disk}G"
    elif ((current_disk_bytes > target_disk_bytes)); then
      wslab_log WARN "$name scsi0 is $current_disk_size, larger than the declared ${disk}G; disks are never shrunk automatically"
    fi
  else
    template_disk_gb=64
    [[ "$os" == "windows-11" ]] && template_disk_gb=80
    if ((disk > template_disk_gb)); then
      wslab_print_command qm disk resize "$vmid" scsi0 "${disk}G"
    fi
  fi

  if [[ "$secure_boot" == "true" ]]; then
    if [[ "$apply" == "false" ]] || ! qm config "$vmid" 2>/dev/null | grep -q '^efidisk0:'; then
      wslab_run "$apply" qm set "$vmid" --bios ovmf --efidisk0 "${vm_storage}:1,efitype=4m,pre-enrolled-keys=1"
    fi
  fi
  if [[ "$tpm" == "true" ]]; then
    if [[ "$apply" == "false" ]] || ! qm config "$vmid" 2>/dev/null | grep -q '^tpmstate0:'; then
      wslab_run "$apply" qm set "$vmid" --tpmstate0 "${vm_storage}:1,version=v2.0"
    fi
  fi

  gpu_mapping="$(jq -r '.gpuMapping // empty' <<<"$vm")"
  if [[ -n "$gpu_mapping" ]]; then
    jq -e '.features.gpuPassthrough == true' "$definition_file" >/dev/null || wslab_die "$name declares a GPU mapping while gpuPassthrough is disabled"
    host_pci="$(jq -r --arg mapping "$gpu_mapping" '.gpuMappings[$mapping] // empty' "$site_file")"
    [[ -n "$host_pci" ]] || wslab_die "Missing site GPU mapping: $gpu_mapping"
    wslab_run "$apply" qm set "$vmid" --hostpci0 "${host_pci},pcie=1"
  fi

  nic_index=0
  while IFS= read -r nic; do
    network="$(jq -r '.network' <<<"$nic")"
    ip_address="$(jq -r '.ipAddress' <<<"$nic")"
    prefix="$(jq -r '.prefixLength' <<<"$nic")"
    use_gateway="$(jq -r '.defaultGateway // false' <<<"$nic")"
    bridge="$(jq -r --arg demo "$demo" --arg network "$network" '.networkMappings[$demo][$network].bridge' "$site_file")"
    vlan="$(jq -r --arg demo "$demo" --arg network "$network" '.networkMappings[$demo][$network].vlanTag' "$site_file")"
    gateway="$(jq -r --arg network "$network" '.networks[$network].gateway' "$definition_file")"

    if [[ "$apply" == "true" && -z "${checked_bridges[$bridge]:-}" ]]; then
      [[ -d "/sys/class/net/$bridge" ]] || wslab_die "Mapped bridge does not exist: $bridge"
      if jq -e --arg bridge "$bridge" 'any(.hostNetworking.bridges[]; .name == $bridge and .management == false)' "$site_file" >/dev/null; then
        [[ "$(cat "/sys/class/net/$bridge/bridge/vlan_filtering" 2>/dev/null || printf 0)" == "1" ]] || wslab_die "Lab bridge $bridge is not VLAN-aware"
        [[ -z "$(ip -4 -o address show dev "$bridge")" ]] || wslab_die "Lab bridge $bridge unexpectedly has an IPv4 address"
        ! ip -4 route show default dev "$bridge" | grep -q . || wslab_die "Lab bridge $bridge unexpectedly carries a default route"
        bridge_uplink="$(jq -r --arg bridge "$bridge" '.hostNetworking.bridges[] | select(.name == $bridge) | .uplink' "$site_file")"
        [[ "$(cat "/sys/class/net/$bridge_uplink/carrier" 2>/dev/null || printf 0)" == "1" ]] || wslab_die "Lab uplink $bridge_uplink has no carrier"
      fi
      checked_bridges[$bridge]=1
    fi
    if [[ "$apply" == "true" && "$vlan" -gt 0 ]] && jq -e --arg bridge "$bridge" 'any(.hostNetworking.bridges[]; .name == $bridge)' "$site_file" >/dev/null; then
      jq -e --arg bridge "$bridge" --argjson vlan "$vlan" 'any(.hostNetworking.bridges[]; .name == $bridge and (.allowedVlans | index($vlan)) != null)' "$site_file" >/dev/null || wslab_die "VLAN $vlan is not approved on lab bridge $bridge"
    fi

    net_config="virtio,bridge=${bridge},firewall=1"
    [[ "$vlan" -gt 0 ]] && net_config+=",tag=${vlan}"
    wslab_run "$apply" qm set "$vmid" "--net${nic_index}" "$net_config"
    ipconfig="ip=${ip_address}/${prefix}"
    [[ "$use_gateway" == "true" ]] && ipconfig+=",gw=${gateway}"
    wslab_run "$apply" qm set "$vmid" "--ipconfig${nic_index}" "$ipconfig"
    ((nic_index += 1))
  done < <(jq -c '.nics[]' <<<"$vm")

  wslab_run "$apply" qm set "$vmid" --ciuser "$guest_user" --sshkeys "$(jq -r '.guestAccess.sshPublicKeyFile' "$site_file")" --nameserver "$dns_servers" --searchdomain "$domain_name"

  snippet_name="wslab-${demo}-${vmid}.ps1"
  snippet_volume="${snippet_storage}:snippets/${snippet_name}"
  if [[ "$apply" == "true" ]]; then
    snippet_path="$(pvesm path "$snippet_volume")"
    mkdir -p "$(dirname "$snippet_path")"
    umask 027
    # Guest role configuration is intentionally deferred to Configure-LabGuests.sh.
    # That phase synchronizes the current signed/reviewed payload and supplies secrets
    # only over QEMU Guest Agent stdin. Cloudbase user data therefore remains secret-free.
    # PowerShell variables must remain literal in the guest snippet.
    # shellcheck disable=SC2016
    printf '%s\n' '#ps1_sysnative' \
      '$ErrorActionPreference = "Stop"' \
      "\$report = 'C:\\ProgramData\\WindowsServerLab\\Reports\\cloudbase-userdata-$vmid.json'" \
      "New-Item -Path (Split-Path -Parent \$report) -ItemType Directory -Force | Out-Null" \
      "[ordered]@{ schemaVersion = 1; status = 'specialized'; vmId = $vmid; role = '$role'; timestamp = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath \$report -Encoding UTF8" \
      >"$snippet_path"
    chmod 0640 "$snippet_path"
    qm set "$vmid" --cicustom "user=${snippet_volume}" >/dev/null
    qm cloudinit update "$vmid" >/dev/null
  else
    wslab_log PLAN "write non-secret bootstrap snippet $snippet_volume for role $role"
    wslab_print_command qm set "$vmid" --cicustom "user=${snippet_volume}"
  fi

  if [[ "$start_after_deploy" == "true" ]]; then
    if [[ "$apply" == "false" ]] || [[ "$(qm status "$vmid" | awk '{print $2}')" != "running" ]]; then
      wslab_run "$apply" qm start "$vmid"
    fi
    if [[ "$apply" == "true" ]]; then
      wslab_log INFO "Waiting for QEMU Guest Agent on $name ($vmid)"
      wslab_wait_for_guest_agent "$vmid" "$guest_agent_timeout"
    else
      wslab_log PLAN "wait up to ${guest_agent_timeout}s for the QEMU Guest Agent on $name ($vmid)"
    fi
  fi
done < <(wslab_profile_vms "$definition_file" "$profile")

summary="$(jq -n --arg demo "$demo" --arg profile "$profile" --arg mode "$([[ "$apply" == "true" ]] && printf apply || printf plan)" --arg domain "$domain_name" --argjson created "$created" --argjson reconciled "$updated" '{schemaVersion:2,demo:$demo,profile:$profile,mode:$mode,domain:$domain,created:$created,reconciled:$reconciled,timestamp:(now|todate)}')"
if [[ "$apply" == "true" ]]; then
  report_file="$report_directory/deploy-${demo}-${profile}-$(date -u +%Y%m%dT%H%M%SZ).json"
  printf '%s\n' "$summary" >"$report_file"
  wslab_log INFO "Deployment report: $report_file"
else
  printf '%s\n' "$summary"
fi

wslab_log INFO "$demo/$profile provisioning completed; guest validation is a separate release gate"
