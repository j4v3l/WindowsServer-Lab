#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/../Proxmox/lib/common.sh"

query="$(jq -c .)"
os="$(jq -r '.os // empty' <<<"$query")"
site_file="$(jq -r '.site_file // empty' <<<"$query")"
case "$os" in
  server-2025|windows-11) ;;
  *) jq -n --arg os "$os" '{status:"unowned",input_digest:"invalid",message:("Unsupported template OS: " + $os)}'; exit 0 ;;
esac

if [[ ! -r "$site_file" ]]; then
  jq -n '{status:"unowned",input_digest:"invalid",message:"Site configuration is not readable"}'
  exit 0
fi

template_id="$(jq -r --arg os "$os" '.proxmox.templates[$os]' "$site_file")"
input_digest="$(wslab_template_input_sha256 "$site_file" "$os")"

status=absent
message="Template $template_id is absent and will be built."
if command -v qm >/dev/null 2>&1 && wslab_qm_exists "$template_id"; then
  template_config="$(qm config "$template_id")"
  if [[ "$(wslab_qm_name "$template_id")" != "wslab-${os}" ]] || ! wslab_qm_has_tag "$template_id" wslab-build; then
    status=unowned
    message="Template ID $template_id is occupied by an unowned VM."
  elif ! grep -Eq '^template: 1$' <<<"$template_config"; then
    build_marker="^description: Packer ephemeral build VM; WSLAB-BUILD-RUN=${os}-${template_id}-[0-9]{8}T[0-9]{6}Z-[0-9]+$"
    if grep -Eq "$build_marker" <<<"$template_config" && \
      grep -Eq '^status: stopped$' < <(qm status "$template_id") && \
      ! grep -Eq '^lock:' <<<"$template_config"; then
      status=interrupted
      message="Template build $template_id was interrupted after Packer established ownership and can be recovered automatically."
    else
      status=unowned
      message="Template ID $template_id is occupied by a running, locked, or malformed build VM."
    fi
  elif certification_error="$(wslab_require_template_certification "$site_file" "$os" "$template_id" 2>&1)"; then
    status=current
    message="Template $template_id is current and certified."
  else
    status=stale
    message="$certification_error"
  fi
fi

jq -n --arg status "$status" --arg input_digest "$input_digest" --arg message "$message" '{status:$status,input_digest:$input_digest,message:$message}'
