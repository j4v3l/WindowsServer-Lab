#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

site_file=""
os=""
confirmation=""
setup_keys_file=""
while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --os) os="${2:-}"; shift 2 ;;
    --confirm) confirmation="${2:-}"; shift 2 ;;
    --setup-keys) setup_keys_file="${2:-}"; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$os" in server-2025|windows-11) ;; *) printf '%s\n' '--os must be server-2025 or windows-11' >&2; exit 2 ;; esac
[[ -r "$site_file" ]] || { printf '%s\n' '--site must name a readable site.json' >&2; exit 2; }
site_file="$(cd "$(dirname "$site_file")" && pwd)/$(basename "$site_file")"
template_id="$(jq -r --arg os "$os" '.proxmox.templates[$os]' "$site_file")"
expected="rebuild-${os}-${template_id}"
[[ "$confirmation" == "$expected" ]] || { printf 'Destructive confirmation must be exactly: %s\n' "$expected" >&2; exit 2; }

resource=module.foundation.terraform_data.windows_11_template
[[ "$os" == "server-2025" ]] && resource=module.foundation.terraform_data.server_2025_template
arguments=(
  -chdir="$REPO_ROOT/terraform"
  apply
  -auto-approve
  -parallelism=1
  -replace="$resource"
  -var="site_config_path=$site_file"
  -var=allow_template_rebuild=true
)
if [[ -n "$setup_keys_file" ]]; then
  arguments+=("-var=setup_keys_file=$setup_keys_file")
fi
umask 077
terraform "${arguments[@]}"
