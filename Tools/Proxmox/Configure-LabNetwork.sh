#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
apply="false"

usage() {
  printf 'Usage: %s --site <json> [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || { usage >&2; exit 2; }
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
jq -e '.schemaVersion == 2 and (.hostNetworking.bridges | length) == 1' "$site_file" >/dev/null || wslab_die "Exactly one lab host bridge is required"

bridge_name="$(jq -r '.hostNetworking.bridges[0].name' "$site_file")"
uplink="$(jq -r '.hostNetworking.bridges[0].uplink' "$site_file")"
management="$(jq -r '.hostNetworking.bridges[0].management' "$site_file")"
vlan_aware="$(jq -r '.hostNetworking.bridges[0].vlanAware' "$site_file")"
allowed_vlans="$(jq -r '.hostNetworking.bridges[0].allowedVlans | sort | join(" ")' "$site_file")"

[[ "$bridge_name" =~ ^vmbr[0-9]+$ ]] || wslab_die "Unsafe bridge name: $bridge_name"
[[ "$uplink" =~ ^[A-Za-z0-9_.-]+$ ]] || wslab_die "Unsafe uplink name: $uplink"
[[ "$management" == "false" && "$vlan_aware" == "true" ]] || wslab_die "The managed lab bridge must be VLAN-aware and explicitly non-management"
[[ -n "$allowed_vlans" ]] || wslab_die "At least one allowed VLAN is required"

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "create or reconcile unnumbered VLAN-aware bridge $bridge_name on dedicated uplink $uplink"
  wslab_log PLAN "allow tagged VLANs: $allowed_vlans"
  wslab_log PLAN "refuse the active default-route interface and never modify vmbr0"
  wslab_log PLAN "write /etc/network/interfaces.d/windows-server-lab after a root-only backup, then bring up only $bridge_name"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
wslab_require_proxmox
for command in bridge ifquery ifreload ifup ip readlink; do wslab_require_command "$command"; done
[[ -d "/sys/class/net/$uplink" ]] || wslab_die "Configured uplink does not exist: $uplink"

management_device="$(ip -4 route show default | awk 'NR == 1 {for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}')"
[[ -n "$management_device" ]] || wslab_die "Unable to identify the Proxmox management/default-route interface"
[[ "$bridge_name" != "$management_device" && "$uplink" != "$management_device" ]] || wslab_die "Refusing to manage the default-route interface $management_device"
if [[ -L "/sys/class/net/$uplink/master" ]]; then
  uplink_master="$(basename "$(readlink -f "/sys/class/net/$uplink/master")")"
  [[ "$uplink_master" != "$management_device" ]] || wslab_die "Uplink $uplink is enslaved to management bridge $management_device"
  [[ "$uplink_master" == "$bridge_name" ]] || wslab_die "Uplink $uplink already belongs to unrelated bridge $uplink_master"
fi

# A configured-but-not-auto physical interface reports carrier=0 while it is
# administratively down. Raise only this already-validated, non-management
# uplink, then health-check actual link carrier before writing configuration.
uplink_was_up="false"
ip link show dev "$uplink" | grep -q '<[^>]*UP[^>]*>' && uplink_was_up="true"
ip link set dev "$uplink" up
carrier_deadline="$(( $(awk '{print int($1)}' /proc/uptime) + 15 ))"
while [[ "$(cat "/sys/class/net/$uplink/carrier" 2>/dev/null || printf 0)" != "1" ]]; do
  if (( $(awk '{print int($1)}' /proc/uptime) >= carrier_deadline )); then
    [[ "$uplink_was_up" == "true" ]] || ip link set dev "$uplink" down
    wslab_die "Uplink $uplink has no physical carrier; connect it to the VLAN 90/100 trunk before applying"
  fi
  sleep 1
done

grep -Eq '^source[[:space:]]+/etc/network/interfaces\.d/\*$' /etc/network/interfaces || wslab_die "/etc/network/interfaces does not include interfaces.d"
config_path='/etc/network/interfaces.d/windows-server-lab'
[[ ! -L "$config_path" ]] || wslab_die "Refusing to replace symlinked network configuration: $config_path"
backup_root='/var/lib/windows-server-lab/network-backups'
backup_path="$backup_root/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$backup_path"
if [[ -e "$config_path" ]]; then
  [[ -f "$config_path" ]] || wslab_die "Managed network configuration path is not a regular file"
  grep -Fq '# Managed by WindowsServerLab' "$config_path" || wslab_die "Existing $config_path is not owned by WindowsServerLab"
  install -m 0600 "$config_path" "$backup_path/windows-server-lab.before"
else
  : >"$backup_path/config-was-absent"
  chmod 0600 "$backup_path/config-was-absent"
fi

temporary_config="$(mktemp /etc/network/interfaces.d/windows-server-lab.XXXXXX)"
cleanup_temporary() {
  [[ -z "${temporary_config:-}" ]] || rm -f -- "$temporary_config"
}
trap cleanup_temporary EXIT
{
  printf '%s\n' '# Managed by WindowsServerLab. Do not add management addressing here.'
  printf 'auto %s\niface %s inet manual\n' "$bridge_name" "$bridge_name"
  printf '\tbridge-ports %s\n' "$uplink"
  printf '%s\n' $'\tbridge-stp off' $'\tbridge-fd 0' $'\tbridge-vlan-aware yes'
  printf '\tbridge-vids %s\n' "$allowed_vlans"
} >"$temporary_config"
chmod 0600 "$temporary_config"
ifquery --interfaces "$temporary_config" "$bridge_name" >/dev/null || wslab_die "Generated bridge configuration did not pass ifquery"
install -m 0600 "$temporary_config" "$config_path"
rm -f -- "$temporary_config"
temporary_config=""

if ip link show "$bridge_name" >/dev/null 2>&1; then
  ifreload -u "$bridge_name"
else
  ifup "$bridge_name"
fi

[[ "$(cat "/sys/class/net/$bridge_name/bridge/vlan_filtering" 2>/dev/null || printf 0)" == "1" ]] || wslab_die "Bridge $bridge_name did not enable VLAN filtering"
[[ -z "$(ip -4 -o address show dev "$bridge_name")" ]] || wslab_die "Bridge $bridge_name unexpectedly received an IPv4 address"
! ip -4 route show default dev "$bridge_name" | grep -q . || wslab_die "Bridge $bridge_name unexpectedly owns a default route"
[[ "$(ip -4 route show default | awk 'NR == 1 {for (i=1; i<=NF; i++) if ($i == "dev") {print $(i+1); exit}}')" == "$management_device" ]] || wslab_die "The management default route changed unexpectedly"
wslab_log PASS "Configured isolated lab bridge $bridge_name on $uplink for VLANs $allowed_vlans; management remains on $management_device"
wslab_log INFO "Network backup: $backup_path"
