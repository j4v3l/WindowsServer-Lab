#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

demo=""
profile="smoke"
site_file=""
apply="false"
confirmation=""
skip_backup="false"

while (($#)); do
  case "$1" in
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --confirm) confirmation="${2:-}"; shift 2 ;;
    --skip-backup) skip_backup="true"; shift ;;
    --apply) apply="true"; shift ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$demo" && -n "$site_file" ]] || wslab_die "Usage: $0 --demo <name> --profile <smoke|core|full> --site <file> [--apply --confirm <demo-profile>] [--skip-backup]"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$demo" "$profile" "$site_file"
definition_file="$(wslab_definition_path "$demo")"
snippet_storage="$(jq -r '.proxmox.snippetStorage' "$site_file")"

if [[ "$apply" == "true" ]]; then
  [[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
  [[ "$confirmation" == "${demo}-${profile}" ]] || wslab_die "Destructive confirmation must be exactly: ${demo}-${profile}"
  wslab_require_proxmox
  if [[ "$skip_backup" == "false" && "$(jq -r '.features.backupBeforeRemove // true' "$site_file")" == "true" ]]; then
    "$SCRIPT_DIR/Backup-Lab.sh" --demo "$demo" --profile "$profile" --site "$site_file" --apply
  fi
fi

wslab_log INFO "$([[ "$apply" == "true" ]] && printf APPLY || printf PLAN) removal for $demo/$profile"
mapfile -t vm_records < <(wslab_profile_vms "$definition_file" "$profile")
for ((index=${#vm_records[@]} - 1; index >= 0; index--)); do
  vm="${vm_records[$index]}"
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  if [[ "$apply" == "true" ]]; then
    if ! wslab_qm_exists "$vmid"; then
      wslab_log INFO "$name ($vmid) already absent"
      continue
    fi
    [[ "$(wslab_qm_name "$vmid")" == "$name" ]] || wslab_die "VM ID $vmid name mismatch"
    wslab_qm_has_tag "$vmid" wslab || wslab_die "Refusing to remove unowned VM $vmid"
    qm stop "$vmid" >/dev/null 2>&1 || true
    qm destroy "$vmid" --purge 1 --destroy-unreferenced-disks 1
    snippet_volume="${snippet_storage}:snippets/wslab-${demo}-${vmid}.ps1"
    if snippet_path="$(pvesm path "$snippet_volume" 2>/dev/null)" && [[ -f "$snippet_path" ]]; then
      [[ "$(basename "$snippet_path")" == "wslab-${demo}-${vmid}.ps1" ]] || wslab_die "Resolved snippet path is not the expected owned file: $snippet_path"
      rm -f -- "$snippet_path"
    fi
  else
    wslab_print_command qm stop "$vmid"
    wslab_print_command qm destroy "$vmid" --purge 1 --destroy-unreferenced-disks 1
  fi
done

wslab_log INFO "Removal operation completed"
