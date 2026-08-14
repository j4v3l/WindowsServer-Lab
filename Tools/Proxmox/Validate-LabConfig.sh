#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || wslab_die "Usage: $0 --site <file>"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"

definition_file="$(wslab_definition_path)"
count="$(jq '.virtualMachines | length' "$definition_file")"
servers="$(jq '[.virtualMachines[] | select(.os == "server-2025")] | length' "$definition_file")"
clients="$(jq '[.virtualMachines[] | select(.os == "windows-11")] | length' "$definition_file")"
memory="$(jq '[.virtualMachines[].memoryMB] | add' "$definition_file")"
cores="$(jq '[.virtualMachines[].cores] | add' "$definition_file")"
disk="$(wslab_virtual_machines "$definition_file" | jq -s '[.[] | .diskGB + ((.dataDisks // []) | map(.sizeGB) | add // 0)] | add')"

wslab_log INFO "Validated Asgard: $count VMs ($servers servers, $clients client), ${cores} vCPU, ${memory} MB RAM, ${disk} GB thin-provisioned disk"
