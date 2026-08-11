#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

demo=""
profile=""
site_file=""

while (($#)); do
  case "$1" in
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$demo" && -n "$profile" && -n "$site_file" ]] || wslab_die "Usage: $0 --demo <asgard|olympus> --profile <smoke|core|full> --site <file>"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$demo" "$profile" "$site_file"

definition_file="$(wslab_definition_path "$demo")"
count="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile))] | length' "$definition_file")"
memory="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile)) | (.profileResourceOverrides[$profile].memoryMB // .memoryMB)] | add' "$definition_file")"
cores="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile)) | (.profileResourceOverrides[$profile].cores // .cores)] | add' "$definition_file")"
disk="$(wslab_profile_vms "$definition_file" "$profile" | jq -s '[.[] | .diskGB + ((.dataDisks // []) | map(.sizeGB) | add // 0)] | add')"

wslab_log INFO "Validated $demo/$profile: $count VMs, ${cores} vCPU, ${memory} MB RAM, ${disk} GB provisioned disk"
