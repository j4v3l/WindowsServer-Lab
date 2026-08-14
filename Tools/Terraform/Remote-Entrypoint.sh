#!/usr/bin/env bash

set -Eeuo pipefail

runtime="${1:?runtime directory is required}"
node="${2:?Proxmox node is required}"
operation="${3:?operation is required}"
preflight_mode="${4:-__WSLAB_EMPTY__}"
template_os="${5:-__WSLAB_EMPTY__}"
allow_template_rebuild="${6:-false}"
setup_keys_present="${7:-__WSLAB_EMPTY__}"
backup_inventory_base64="${8:-__WSLAB_EMPTY__}"

[[ "$preflight_mode" != '__WSLAB_EMPTY__' ]] || preflight_mode=""
[[ "$template_os" != '__WSLAB_EMPTY__' ]] || template_os=""
[[ "$setup_keys_present" != '__WSLAB_EMPTY__' ]] || setup_keys_present=""
[[ "$backup_inventory_base64" != '__WSLAB_EMPTY__' ]] || backup_inventory_base64=""

case "$runtime" in /tmp/windows-server-lab-*) ;; *) printf 'Unsafe runtime directory: %s\n' "$runtime" >&2; exit 2 ;; esac
[[ "$node" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'Invalid Proxmox node\n' >&2; exit 2; }

export WSLAB_PROXMOX_NODE="$node"
site_file="$runtime/$(basename "${WSLAB_SITE_FILE:-site.json}")"
[[ -r "$site_file" ]] || site_file="$runtime/site.json"
lab_file="$runtime/LabConfig/lab.json"
setup_keys_file=""
[[ "$setup_keys_present" == 'present' ]] && setup_keys_file="$runtime/setup-keys.json"

case "$operation" in
  preflight)
    jq -n --arg mode "$preflight_mode" --arg site_file "$site_file" --arg lab_file "$lab_file" \
      '{mode:$mode,site_file:$site_file,lab_file:$lab_file}' |
      "$runtime/Tools/Terraform/Preflight.sh"
    ;;
  template-status)
    jq -n --arg os "$template_os" --arg site_file "$site_file" '{os:$os,site_file:$site_file}' |
      "$runtime/Tools/Terraform/Template-Status.sh"
    ;;
  reconcile-template)
    WSLAB_ALLOW_TEMPLATE_REBUILD="$allow_template_rebuild" \
      WSLAB_OS="$template_os" \
      WSLAB_SETUP_KEYS_FILE="$setup_keys_file" \
      WSLAB_SITE_FILE="$site_file" \
      "$runtime/Tools/Terraform/Reconcile-Template.sh"
    ;;
  configure-guests)
    "$runtime/Tools/Proxmox/Configure-LabGuests.sh" \
      --site "$site_file" \
      --secrets "$runtime/guest-secrets.json" \
      --apply
    ;;
  backup-lab)
    backup_inventory_json="$(printf '%s' "$backup_inventory_base64" | base64 --decode)"
    WSLAB_SITE_FILE="$site_file" WSLAB_APPLY=true WSLAB_BACKUP_INVENTORY_JSON="$backup_inventory_json" \
      "$runtime/Tools/Proxmox/Backup-Lab.sh"
    ;;
  *)
    printf 'Unsupported remote operation: %s\n' "$operation" >&2
    exit 2
    ;;
esac
