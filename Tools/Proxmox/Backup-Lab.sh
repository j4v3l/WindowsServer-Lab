#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

demo=""
profile="smoke"
site_file=""
apply="false"

while (($#)); do
  case "$1" in
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$demo" && -n "$site_file" ]] || wslab_die "Usage: $0 --demo <name> --profile <smoke|core|full> --site <file> [--apply]"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$demo" "$profile" "$site_file"
definition_file="$(wslab_definition_path "$demo")"
backup_storage="$(jq -r '.proxmox.backupStorage' "$site_file")"
retention="$(jq -r '.proxmox.backupRetention | "keep-last=\(.keepLast),keep-daily=\(.keepDaily),keep-weekly=\(.keepWeekly),keep-monthly=\(.keepMonthly)"' "$site_file")"
report_directory="$(wslab_report_directory "$site_file")"

if [[ "$apply" == "true" ]]; then
  [[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
  wslab_require_proxmox
  wslab_require_command vzdump
fi

wslab_log INFO "$([[ "$apply" == "true" ]] && printf APPLY || printf PLAN) backup for $demo/$profile"
backup_count=0
while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  role="$(jq -r '.role' <<<"$vm")"
  if [[ "$apply" == "true" ]]; then
    wslab_qm_exists "$vmid" || wslab_die "VM $vmid ($name) does not exist"
    wslab_qm_has_tag "$vmid" wslab || wslab_die "VM $vmid is not owned by WindowsServerLab"
  fi
  [[ "$role" != *-dc ]] || wslab_log WARN "$name also requires a tested Windows System State backup; a VM backup alone is not the AD recovery procedure"
  wslab_run "$apply" vzdump "$vmid" --storage "$backup_storage" --mode snapshot --compress zstd --prune-backups "$retention" --notes-template "WindowsServerLab ${demo}/${profile} {{guestname}}"
  ((backup_count += 1))
done < <(wslab_profile_vms "$definition_file" "$profile")

if [[ "$apply" == "true" ]]; then
  mkdir -p "$report_directory"
  report_file="$report_directory/backup-${demo}-${profile}-$(date -u +%Y%m%dT%H%M%SZ).json"
  jq -n --arg demo "$demo" --arg profile "$profile" --arg storage "$backup_storage" --arg retention "$retention" --argjson vmCount "$backup_count" '{schemaVersion:2,demo:$demo,profile:$profile,storage:$storage,retention:$retention,vmCount:$vmCount,passed:true,timestamp:(now|todate)}' >"$report_file"
  wslab_log INFO "Backup evidence: $report_file"
fi
wslab_log INFO "Backup operation completed"
