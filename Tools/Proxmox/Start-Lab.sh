#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

demo=""
profile=""
site_file=""
activate="false"
apply="false"

usage() {
  printf 'Usage: %s --demo asgard --profile smoke --site <json> [--activate] [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --activate) activate="true"; shift ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ "$demo" == "asgard" && "$profile" == "smoke" && -n "$site_file" ]] || { usage >&2; exit 2; }
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$demo" "$profile" "$site_file"

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "start the complete Asgard smoke lab only after vmbr1 and both template certificates are valid"
  "$SCRIPT_DIR/Deploy-Lab.sh" --demo "$demo" --profile "$profile" --site "$site_file"
  "$SCRIPT_DIR/Configure-LabGuests.sh" --demo "$demo" --profile "$profile" --site "$site_file"
  if [[ "$activate" == "true" ]]; then
    "$SCRIPT_DIR/Activate-LabGuests.sh" --demo "$demo" --profile "$profile" --site "$site_file" --action activate
  else
    wslab_log PLAN "skip activation; licensing remains a release-blocking acceptance item"
  fi
  "$SCRIPT_DIR/Test-Lab.sh" --demo "$demo" --profile "$profile" --site "$site_file" --phase full --offline
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on the target Proxmox node"
wslab_require_proxmox
"$SCRIPT_DIR/Deploy-Lab.sh" --demo "$demo" --profile "$profile" --site "$site_file" --apply
"$SCRIPT_DIR/Configure-LabGuests.sh" --demo "$demo" --profile "$profile" --site "$site_file" --apply
if [[ "$activate" == "true" ]]; then
  "$SCRIPT_DIR/Activate-LabGuests.sh" --demo "$demo" --profile "$profile" --site "$site_file" --action activate --apply
else
  wslab_log WARN "Activation was not requested; the final full acceptance gate is expected to report licensing as incomplete"
fi
"$SCRIPT_DIR/Test-Lab.sh" --demo "$demo" --profile "$profile" --site "$site_file" --phase full
