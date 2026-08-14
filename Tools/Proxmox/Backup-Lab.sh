#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file="${WSLAB_SITE_FILE:-}"
apply="${WSLAB_APPLY:-false}"

while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || wslab_die "Usage: $0 --site <file> [--apply]"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"
definition_file="$(wslab_definition_path)"
backup_inventory_json="${WSLAB_BACKUP_INVENTORY_JSON:-}"
if [[ -n "$backup_inventory_json" ]]; then
  jq -e 'type == "array" and all(.[]; (.id | numbers) and (.name | strings) and (.role | strings))' >/dev/null <<<"$backup_inventory_json" || wslab_die "Backup inventory is invalid"
fi
backup_storage="$(jq -r '.proxmox.backupStorage' "$site_file")"
retention="$(jq -r '.proxmox.backupRetention | "keep-last=\(.keepLast),keep-daily=\(.keepDaily),keep-weekly=\(.keepWeekly),keep-monthly=\(.keepMonthly)"' "$site_file")"
report_directory="$(wslab_report_directory "$site_file")"

if [[ "$apply" == "true" ]]; then
  [[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
  wslab_require_proxmox
  wslab_require_command vzdump
fi

wslab_log INFO "$([[ "$apply" == "true" ]] && printf APPLY || printf PLAN) backup for every Terraform-managed lab VM"
backup_count=0
while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  role="$(jq -r '.role' <<<"$vm")"
  if [[ "$apply" == "true" ]]; then
    wslab_qm_exists "$vmid" || wslab_die "VM $vmid ($name) does not exist"
    [[ "$(wslab_qm_name "$vmid")" == "$name" ]] || wslab_die "VM $vmid name does not match protected inventory identity $name"
    wslab_qm_has_tag "$vmid" wslab || wslab_die "VM $vmid is not owned by WindowsServerLab"
  fi
  [[ "$role" != *-dc ]] || wslab_log WARN "$name also requires a tested Windows System State backup; a VM backup alone is not the AD recovery procedure"
  wslab_run "$apply" vzdump "$vmid" --storage "$backup_storage" --mode snapshot --compress zstd --prune-backups "$retention" --notes-template "WindowsServerLab terraform {{guestname}}"
  ((backup_count += 1))
done < <(
  if [[ -n "$backup_inventory_json" ]]; then
    jq -c 'sort_by(.id)[]' <<<"$backup_inventory_json"
  else
    wslab_virtual_machines "$definition_file"
  fi
)

if [[ "$apply" == "true" ]]; then
  mkdir -p "$report_directory"
  report_file="$report_directory/backup-terraform-$(date -u +%Y%m%dT%H%M%SZ).json"
  jq -n --arg storage "$backup_storage" --arg retention "$retention" --argjson vmCount "$backup_count" '{schemaVersion:3,lab:"asgard",storage:$storage,retention:$retention,vmCount:$vmCount,passed:true,timestamp:(now|todate)}' >"$report_file"
  wslab_log INFO "Backup evidence: $report_file"
fi
wslab_log INFO "Backup operation completed"
