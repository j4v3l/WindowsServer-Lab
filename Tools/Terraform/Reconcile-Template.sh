#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/../Proxmox/lib/common.sh"

site_file="${WSLAB_SITE_FILE:?WSLAB_SITE_FILE is required}"
os="${WSLAB_OS:?WSLAB_OS is required}"
allow_rebuild="${WSLAB_ALLOW_TEMPLATE_REBUILD:-false}"
setup_keys_file="${WSLAB_SETUP_KEYS_FILE:-}"
case "$os" in server-2025|windows-11) ;; *) wslab_die "Unsupported template OS: $os" ;; esac
[[ "$allow_rebuild" == "true" || "$allow_rebuild" == "false" ]] || wslab_die "WSLAB_ALLOW_TEMPLATE_REBUILD must be true or false"
wslab_validate_inputs "$site_file"
[[ "$(id -u)" -eq 0 ]] || wslab_die "Template reconciliation must run as root on the Proxmox node"
wslab_require_proxmox
wslab_require_command flock

# Template builds share one temporary address and one certification VM ID, so
# serialize the complete status/build/certification transaction. The lock is
# released automatically if Terraform or SSH is interrupted. Close the lock
# descriptor in long-running children so QEMU/swtpm cannot inherit it and keep
# a stale lock alive after an interrupted remote session.
exec 9>/run/lock/windows-server-lab-template-reconcile.lock
flock -n 9 || wslab_die 'Another Windows template reconciliation is already running'
export WSLAB_TEMPLATE_RECONCILE_LOCK_HELD=true

template_id="$(jq -r --arg os "$os" '.proxmox.templates[$os]' "$site_file")"
canary_id="$(jq -r '.templateCertification.vmId' "$site_file")"

# Recover the one shared certification slot after an interrupted Terraform
# connection. Ownership must match every marker the certification workflow
# writes; anything else is left untouched and blocks the run for review.
if wslab_qm_exists "$canary_id"; then
  canary_config="$(qm config "$canary_id")"
  if ! grep -Eq '^description: WSLAB-CERT-RUN=cert-(server-2025|windows-11)-[0-9]+-[0-9]{8}T[0-9]{6}Z-[0-9]+$' <<<"$canary_config" ||
    ! grep -Eq '^name: WSLAB-(S25|W11)-[AB]$' <<<"$canary_config" ||
    ! wslab_qm_has_tag "$canary_id" wslab ||
    ! wslab_qm_has_tag "$canary_id" wslab-certification ||
    grep -Eq '^template: 1$' <<<"$canary_config" ||
    grep -Eq '^lock:' <<<"$canary_config"; then
    wslab_die "Certification VM ID $canary_id is occupied without safe stale-canary ownership markers"
  fi
  wslab_log WARN "Removing safely identified stale certification canary $canary_id"
  qm stop "$canary_id" --skiplock 1 >/dev/null 2>&1 || true
  qm destroy "$canary_id" --purge 1 --destroy-unreferenced-disks 1
fi

status_json="$(jq -n --arg os "$os" --arg site_file "$site_file" '{os:$os,site_file:$site_file}' | "$SCRIPT_DIR/Template-Status.sh")"
status="$(jq -r '.status' <<<"$status_json")"

case "$status" in
  current)
    wslab_log PASS "Template $template_id for $os is already current and certified"
    exit 0
    ;;
  absent) ;;
  interrupted)
    [[ "$(wslab_qm_name "$template_id")" == "wslab-${os}" ]] || wslab_die "Interrupted build name mismatch; refusing recovery"
    wslab_qm_has_tag "$template_id" wslab-build || wslab_die "Interrupted build lacks the wslab-build ownership tag"
    template_config="$(qm config "$template_id")"
    ! grep -Eq '^template: 1$' <<<"$template_config" || wslab_die "Interrupted build unexpectedly became a template; refusing recovery"
    grep -Eq '^status: stopped$' < <(qm status "$template_id") || wslab_die "Interrupted build is running; refusing recovery"
    ! grep -Eq '^lock:' <<<"$template_config" || wslab_die "Interrupted build is locked; refusing recovery"
    grep -Eq "^description: Packer ephemeral build VM; WSLAB-BUILD-RUN=${os}-${template_id}-[0-9]{8}T[0-9]{6}Z-[0-9]+$" <<<"$template_config" || wslab_die "Interrupted build marker mismatch; refusing recovery"
    build_run_id="$(sed -n 's/^description: Packer ephemeral build VM; WSLAB-BUILD-RUN=//p' <<<"$template_config")"
    build_process_id="${build_run_id##*-}"
    iso_storage="$(jq -r '.proxmox.isoStorage' "$site_file")"
    interrupted_media="$(awk -F': ' '$1 == "sata0" {print $2}' <<<"$template_config" | cut -d, -f1)"
    expected_media_prefix="${iso_storage}:iso/wslab-install-${os}-${template_id}-"
    if [[ "$interrupted_media" == "$expected_media_prefix"* ]]; then
      interrupted_media_suffix="${interrupted_media#"$expected_media_prefix"}"
      [[ "$interrupted_media_suffix" =~ ^[0-9]+\.iso$ ]] || wslab_die "Interrupted answer-media name is malformed; refusing recovery"
    else
      interrupted_media=""
    fi
    wslab_log WARN "Removing safely identified interrupted Packer builder $template_id for $os"
    qm destroy "$template_id" --purge 1 --destroy-unreferenced-disks 1
    if [[ -n "$interrupted_media" ]]; then
      wslab_log WARN "Removing interrupted build answer media $interrupted_media"
      pvesm free "$interrupted_media"
    fi
    while IFS= read -r interrupted_token_id; do
      [[ "$interrupted_token_id" =~ ^wslab-packer-${template_id}-[0-9]{14}-${build_process_id}$ ]] || wslab_die "Interrupted build token name is malformed; refusing recovery"
      wslab_log WARN "Revoking interrupted build API token $interrupted_token_id"
      pveum user token remove root@pam "$interrupted_token_id"
    done < <(pveum user token list root@pam --output-format json | jq -r --arg suffix "-$build_process_id" --arg prefix "wslab-packer-${template_id}-" '.[] | select((.tokenid | startswith($prefix)) and (.tokenid | endswith($suffix))) | .tokenid')
    ;;
  stale)
    [[ "$allow_rebuild" == "true" ]] || wslab_die "Template $template_id is stale; use the confirmed rebuild command"
    [[ "$(wslab_qm_name "$template_id")" == "wslab-${os}" ]] || wslab_die "Template name mismatch; refusing rebuild"
    wslab_qm_has_tag "$template_id" wslab-build || wslab_die "Template lacks the wslab-build ownership tag"
    qm config "$template_id" | grep -Eq '^template: 1$' || wslab_die "VM $template_id is not a template"
    wslab_log WARN "Removing explicitly confirmed stale template $template_id for $os"
    qm destroy "$template_id" --purge 1 --destroy-unreferenced-disks 1
    ;;
  *) wslab_die "$(jq -r '.message' <<<"$status_json")" ;;
esac

media_volume="$(jq -r --arg os "$os" '.media[$os].volume' "$site_file")"
media_sha256="$(jq -r --arg os "$os" '.media[$os].sha256' "$site_file")"
build_command=(
  "$SCRIPT_DIR/../Proxmox/Build-WindowsTemplate.sh"
  --os "$os"
  --iso "$media_volume"
  --iso-sha256 "$media_sha256"
  --site "$site_file"
  --artifacts "$WSLAB_ROOT/LabConfig/build-artifacts.json"
  --ephemeral-build-secrets
  --apply
)
if [[ -n "$setup_keys_file" ]]; then
  build_command+=(--setup-keys "$setup_keys_file")
fi
"${build_command[@]}" 9>&-
"$SCRIPT_DIR/../Proxmox/Certify-WindowsTemplate.sh" --os "$os" --site "$site_file" --apply 9>&-
wslab_log PASS "Template $template_id for $os was built and certified"
