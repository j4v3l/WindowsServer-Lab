#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
activate="false"
apply="false"

usage() {
  printf 'Usage: %s --site <json> [--activate] [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --activate) activate="true"; shift ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || { usage >&2; exit 2; }
wslab_require_command terraform
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"

terraform_root="$WSLAB_ROOT/terraform"
terraform_args=(-var="site_config_path=$site_file")

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "run the single Terraform plan for the bridge, Packer templates, inventory VMs, and guest convergence"
  terraform -chdir="$terraform_root" plan "${terraform_args[@]}"
  exit 0
fi

terraform -chdir="$terraform_root" apply "${terraform_args[@]}"
if [[ "$activate" == "true" ]]; then
  wslab_log WARN "Windows activation remains an explicit secret-bearing operation and is not part of lab creation"
else
  wslab_log WARN "Activation was not requested; full acceptance will report licensing as incomplete"
fi
