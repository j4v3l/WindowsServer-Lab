#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
mode="lab"
while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || wslab_die "Usage: $0 --site <json> [--mode foundation|lab]"
[[ "$mode" == "foundation" || "$mode" == "lab" ]] || wslab_die "--mode must be foundation or lab"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"
query="$(jq -n --arg mode "$mode" --arg site_file "$site_file" --arg lab_file "$(wslab_definition_path)" '{mode:$mode,site_file:$site_file,lab_file:$lab_file}')"
result="$(printf '%s' "$query" | "$WSLAB_ROOT/Tools/Terraform/Preflight.sh")"
if [[ "$(jq -r '.ready' <<<"$result")" == "true" ]]; then
  wslab_log PASS "$(jq -r '.message' <<<"$result")"
else
  wslab_die "$(jq -r '.message' <<<"$result")"
fi
