#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

os=""
iso=""
iso_sha256=""
site_file=""
artifact_file=""
setup_keys_file=""
ephemeral_build_secrets="false"
apply="false"

while (($#)); do
  case "$1" in
    --os) os="${2:-}"; shift 2 ;;
    --iso) iso="${2:-}"; shift 2 ;;
    --iso-sha256) iso_sha256="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --artifacts) artifact_file="${2:-}"; shift 2 ;;
    --setup-keys) setup_keys_file="${2:-}"; shift 2 ;;
    --ephemeral-build-secrets) ephemeral_build_secrets="true"; shift ;;
    --apply) apply="true"; shift ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

case "$os" in server-2025|server-2022|windows-11) ;; *) wslab_die "--os must be server-2025, server-2022, or windows-11" ;; esac
[[ -n "$iso" && -n "$site_file" ]] || wslab_die "Usage: $0 --os <server-2025|server-2022|windows-11> --iso <local-path|storage:iso/file.iso> --site <file> [--iso-sha256 <sha256>] [--artifacts <json>] [--setup-keys <runtime-json>] [--ephemeral-build-secrets] [--apply]"
[[ "$iso_sha256" =~ ^[A-Fa-f0-9]{64}$ ]] || wslab_die "--iso-sha256 with the approved media digest is required"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
jq -e '.schemaVersion == 2' "$site_file" >/dev/null || wslab_die "Invalid site configuration"
if [[ -n "$artifact_file" ]]; then
  artifact_file="$(wslab_realpath "$artifact_file")"
  [[ -r "$artifact_file" ]] || wslab_die "Build artifact manifest is not readable: $artifact_file"
  jq -e '.schemaVersion == 1 and .cloudbaseInit.url and .cloudbaseInit.sha256' "$artifact_file" >/dev/null || wslab_die "Invalid build artifact manifest"
  PKR_VAR_cloudbase_msi_url="$(jq -r '.cloudbaseInit.url' "$artifact_file")"
  PKR_VAR_cloudbase_msi_sha256="$(jq -r '.cloudbaseInit.sha256' "$artifact_file")"
  export PKR_VAR_cloudbase_msi_url PKR_VAR_cloudbase_msi_sha256
fi
if [[ -n "$setup_keys_file" ]]; then
  setup_keys_file="$(wslab_realpath "$setup_keys_file")"
  [[ -r "$setup_keys_file" ]] || wslab_die "Runtime setup-key file is not readable: $setup_keys_file"
  jq -e --arg os "$os" '.schemaVersion == 1 and (.setupKeys[$os] | strings)' "$setup_keys_file" >/dev/null || wslab_die "Runtime setup-key file does not contain $os"
  PKR_VAR_windows_setup_key="$(jq -r --arg os "$os" '.setupKeys[$os]' "$setup_keys_file")"
  [[ "$PKR_VAR_windows_setup_key" =~ ^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$ ]] || wslab_die "Runtime setup key has an invalid format"
  export PKR_VAR_windows_setup_key
fi

if [[ "$iso" != *:* ]]; then
  [[ -r "$iso" ]] || wslab_die "ISO is not readable: $iso"
  iso="$(wslab_realpath "$iso")"
  wslab_require_command sha256sum
  printf '%s  %s\n' "$iso_sha256" "$iso" | sha256sum --check --status || wslab_die "ISO checksum mismatch"
fi

template_id="$(jq -r --arg os "$os" '.proxmox.templates[$os]' "$site_file")"
node="$(jq -r '.proxmox.node' "$site_file")"
storage="$(jq -r '.proxmox.vmStorage' "$site_file")"
iso_storage="$(jq -r '.proxmox.isoStorage' "$site_file")"
build_bridge="$(jq -r '.templateBuildNetwork.bridge' "$site_file")"
WSLAB_BUILD_IPV4_ADDRESS="$(jq -r '.templateBuildNetwork.address' "$site_file")"
WSLAB_BUILD_IPV4_PREFIX_LENGTH="$(jq -r '.templateBuildNetwork.prefixLength' "$site_file")"
WSLAB_BUILD_IPV4_GATEWAY="$(jq -r '.templateBuildNetwork.gateway' "$site_file")"
WSLAB_BUILD_DNS_SERVERS="$(jq -r '.templateBuildNetwork.dnsServers | join(",")' "$site_file")"
export WSLAB_BUILD_IPV4_ADDRESS WSLAB_BUILD_IPV4_PREFIX_LENGTH WSLAB_BUILD_IPV4_GATEWAY WSLAB_BUILD_DNS_SERVERS
virtio_iso="$(jq -r '.proxmox.virtioIso' "$site_file")"
virtio_iso_sha256="$(jq -r '.proxmox.virtioIsoSha256' "$site_file")"
[[ "$virtio_iso_sha256" =~ ^[A-Fa-f0-9]{64}$ && ! "$virtio_iso_sha256" =~ ^0{64}$ ]] || wslab_die "The site must contain the approved, non-placeholder VirtIO ISO SHA-256 digest"

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "validate Windows media and build template $template_id for $os on $node"
  [[ "$iso" == *:* ]] || wslab_log PLAN "stage the verified Windows ISO in directory-backed storage $iso_storage"
  wslab_log PLAN "extract and hash QEMU Guest Agent, then render an ephemeral checksum-verified WSLABDATA Windows install ISO overlay"
  wslab_log PLAN "use temporary build address $WSLAB_BUILD_IPV4_ADDRESS/$WSLAB_BUILD_IPV4_PREFIX_LENGTH on $build_bridge"
  [[ "$ephemeral_build_secrets" == "false" ]] || wslab_log PLAN "create a four-hour root-scoped PVE API token and random media-build password, then revoke/discard both on exit"
  [[ -z "$setup_keys_file" ]] || wslab_log PLAN "use the runtime-only Microsoft-published setup key for $os; it is not an activation credential"
  wslab_print_command packer init "$WSLAB_ROOT/packer/windows/windows.pkr.hcl"
  wslab_print_command packer build -var "os_type=$os" -var "vm_id=$template_id" -var "node=$node" -var "storage_pool=$storage" -var "build_bridge=$build_bridge" -var "build_ipv4_address=$WSLAB_BUILD_IPV4_ADDRESS" -var 'build_run_id=<unique-run-id>' -var "iso_file=<ephemeral-wslabdata-install-volume>" -var "iso_sha256=<ephemeral-wslabdata-digest>" -var "virtio_iso=$virtio_iso" -var "virtio_iso_sha256=$virtio_iso_sha256" "$WSLAB_ROOT/packer/windows/windows.pkr.hcl"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
wslab_require_proxmox
wslab_require_command packer
wslab_require_command xorriso
wslab_require_command genisoimage
wslab_require_command mount
wslab_require_command mountpoint
wslab_require_command umount
wslab_require_command sha256sum
wslab_require_command python3
wslab_require_command curl
wslab_require_command arping
wslab_log INFO "Template build tools are available"
[[ -d "/sys/class/net/$build_bridge" ]] || wslab_die "Template build bridge does not exist: $build_bridge"
if arping -D -c 3 -w 4 -I "$build_bridge" "$WSLAB_BUILD_IPV4_ADDRESS" >/dev/null 2>&1; then
  wslab_die "Template build address $WSLAB_BUILD_IPV4_ADDRESS answered ARP; choose an unused address"
fi
wslab_log INFO "Template build address passed the live ARP conflict check"
if [[ -n "$setup_keys_file" ]]; then
  setup_keys_mode="$(stat -c '%a' "$setup_keys_file")"
  (( (8#$setup_keys_mode & 077) == 0 )) || wslab_die "Runtime setup-key file must not be readable by group or other users"
fi

answer_directory=""
answer_volume=""
source_mount=""
overlay_mount=""
ephemeral_token_id=""
build_run_id="${os}-${template_id}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
build_succeeded="false"
builder_marker_pid=""
cleanup() {
  local exit_status="$?"
  if [[ -n "$builder_marker_pid" ]]; then
    kill "$builder_marker_pid" >/dev/null 2>&1 || true
    wait "$builder_marker_pid" >/dev/null 2>&1 || true
  fi
  if [[ "$build_succeeded" == "false" ]] && wslab_qm_exists "$template_id"; then
    if qm config "$template_id" 2>/dev/null | grep -Fq "WSLAB-BUILD-RUN=$build_run_id"; then
      wslab_log WARN "Removing failed builder VM $template_id owned by run $build_run_id"
      qm stop "$template_id" --skiplock 1 >/dev/null 2>&1 || true
      qm unlock "$template_id" >/dev/null 2>&1 || true
      qm destroy "$template_id" --purge 1 --destroy-unreferenced-disks 1 >/dev/null 2>&1 || wslab_log WARN "Builder VM $template_id requires manual cleanup"
    else
      wslab_log WARN "VM $template_id exists without this run marker; refusing automatic cleanup"
    fi
  fi
  if [[ -n "$answer_volume" ]]; then
    pvesm free "$answer_volume" >/dev/null 2>&1 || true
  fi
  if [[ -n "$overlay_mount" ]] && mountpoint -q "$overlay_mount"; then
    umount "$overlay_mount" >/dev/null 2>&1 || wslab_log WARN "Temporary overlay mount requires manual cleanup: $overlay_mount"
  fi
  if [[ -n "$source_mount" ]] && mountpoint -q "$source_mount"; then
    umount "$source_mount" >/dev/null 2>&1 || wslab_log WARN "Temporary Windows ISO mount requires manual cleanup: $source_mount"
  fi
  if [[ -n "$answer_directory" && "$answer_directory" == /tmp/windows-server-lab-answer.* ]]; then
    rm -rf -- "$answer_directory"
  fi
  if [[ -n "$ephemeral_token_id" ]]; then
    pveum user token remove root@pam "$ephemeral_token_id" >/dev/null 2>&1 || true
  fi
  unset PKR_VAR_proxmox_token PKR_VAR_windows_password
  unset PKR_VAR_windows_setup_key
  unset WSLAB_QEMU_AGENT_MSI_SHA256
  return "$exit_status"
}
trap cleanup EXIT

if [[ "$ephemeral_build_secrets" == "true" ]]; then
  [[ -z "${PKR_VAR_proxmox_token:-}" && -z "${PKR_VAR_windows_password:-}" ]] || wslab_die "Do not pre-set token/password variables with --ephemeral-build-secrets"
  wslab_require_command openssl
  wslab_require_command pveum
  wslab_log INFO "Creating short-lived build credentials"
  ephemeral_token_id="wslab-packer-${template_id}-$(date -u +%Y%m%d%H%M%S)-$$"
  token_json="$(pveum user token add root@pam "$ephemeral_token_id" --privsep 0 --expire "$(( $(date +%s) + 14400 ))" --output-format json)"
  PKR_VAR_proxmox_url='https://127.0.0.1:8006/api2/json'
  PKR_VAR_proxmox_username="$(jq -r '."full-tokenid"' <<<"$token_json")"
  PKR_VAR_proxmox_token="$(jq -r '.value' <<<"$token_json")"
  token_json=''
  PKR_VAR_windows_password="$(openssl rand -base64 36 | tr -d '\r\n')Aa1!"
  export PKR_VAR_proxmox_url PKR_VAR_proxmox_username PKR_VAR_proxmox_token PKR_VAR_windows_password
  wslab_log INFO "Short-lived build credentials are ready and will be revoked/discarded on exit"
fi

if [[ -r /etc/pve/pve-root-ca.pem ]]; then
  SSL_CERT_FILE=/etc/pve/pve-root-ca.pem
  export SSL_CERT_FILE
fi

for required_var in PKR_VAR_proxmox_url PKR_VAR_proxmox_username PKR_VAR_proxmox_token PKR_VAR_windows_password PKR_VAR_cloudbase_msi_url PKR_VAR_cloudbase_msi_sha256; do
  [[ -n "${!required_var:-}" ]] || wslab_die "Required secret/build environment variable is not set: $required_var"
done
wslab_log INFO "Runtime build inputs are present"
[[ "${PKR_VAR_proxmox_url:-}" == https://* ]] || wslab_die "PKR_VAR_proxmox_url must use HTTPS"
[[ "${PKR_VAR_cloudbase_msi_url:-}" == https://* ]] || wslab_die "PKR_VAR_cloudbase_msi_url must use HTTPS"
[[ "${PKR_VAR_cloudbase_msi_sha256:-}" =~ ^[A-Fa-f0-9]{64}$ ]] || wslab_die "PKR_VAR_cloudbase_msi_sha256 must be a SHA-256 digest"
wslab_log INFO "Runtime build inputs passed format checks"

if wslab_qm_exists "$template_id"; then
  wslab_die "Template ID $template_id already exists; remove it explicitly before rebuilding"
fi
wslab_log INFO "Template ID $template_id is available"
stale_certification_file="$(wslab_template_certification_file "$site_file" "$os" "$template_id")"
stale_certification_junit="$(dirname "$stale_certification_file")/template-${os}-${template_id}.junit.xml"
if [[ -e "$stale_certification_file" || -e "$stale_certification_junit" ]]; then
  wslab_log WARN "Removing stale certification evidence for absent template $template_id"
  rm -f -- "$stale_certification_file" "$stale_certification_junit"
fi

iso_volume="$iso"
if [[ "$iso" != *:* ]]; then
  iso_name="$(basename "$iso")"
  iso_volume="${iso_storage}:iso/${iso_name}"
  iso_target_path="$(pvesm path "$iso_volume")"
  if [[ ! -e "$iso_target_path" ]]; then
    install -d -m 0755 "$(dirname "$iso_target_path")"
    install -m 0644 "$iso" "$iso_target_path"
  fi
fi

iso_path="$(pvesm path "$iso_volume")"
virtio_iso_path="$(pvesm path "$virtio_iso")"
wslab_log INFO "Verifying Windows and VirtIO media checksums"
printf '%s  %s\n' "$iso_sha256" "$iso_path" | sha256sum --check --status || wslab_die "Uploaded Windows ISO checksum mismatch"
printf '%s  %s\n' "$virtio_iso_sha256" "$virtio_iso_path" | sha256sum --check --status || wslab_die "VirtIO ISO checksum mismatch"

answer_directory="$(mktemp -d /tmp/windows-server-lab-answer.XXXXXX)"
umask 077
cloudbase_media_path="$answer_directory/CloudbaseInitSetup.msi"
curl --fail --location --proto '=https' --tlsv1.2 --output "$cloudbase_media_path" "$PKR_VAR_cloudbase_msi_url"
printf '%s  %s\n' "$PKR_VAR_cloudbase_msi_sha256" "$cloudbase_media_path" | sha256sum --check --status || wslab_die "Cloudbase-Init installer checksum mismatch"
qemu_agent_media_path="$answer_directory/qemu-ga-x86_64.msi"
xorriso -osirrox on -indev "$virtio_iso_path" -extract /guest-agent/qemu-ga-x86_64.msi "$qemu_agent_media_path" >/dev/null 2>&1 || wslab_die "Unable to extract QEMU Guest Agent from the verified VirtIO ISO"
[[ -s "$qemu_agent_media_path" ]] || wslab_die "The extracted QEMU Guest Agent installer is empty"
chmod 0600 "$qemu_agent_media_path"
WSLAB_QEMU_AGENT_MSI_SHA256="$(sha256sum "$qemu_agent_media_path" | awk '{print $1}')"
export WSLAB_QEMU_AGENT_MSI_SHA256
case "$os" in
  server-2025) virtio_driver_directory='2k25' ;;
  server-2022) virtio_driver_directory='2k22' ;;
  windows-11) virtio_driver_directory='w11' ;;
esac
for driver_family in vioscsi NetKVM vioserial; do
  driver_destination="$answer_directory/WSLABDRIVERS/$driver_family/$virtio_driver_directory/amd64"
  mkdir -p "$driver_destination"
  xorriso -osirrox on -indev "$virtio_iso_path" -extract "/$driver_family/$virtio_driver_directory/amd64" "$driver_destination" >/dev/null 2>&1 || wslab_die "Unable to extract $driver_family/$virtio_driver_directory drivers from the verified VirtIO ISO"
done
jq -n \
  --arg os "$os" \
  --arg buildRunId "$build_run_id" \
  --arg automationSha256 "$(wslab_template_automation_sha256)" \
  --arg windowsIsoSha256 "${iso_sha256,,}" \
  --arg virtioIsoSha256 "${virtio_iso_sha256,,}" \
  --arg cloudbaseSha256 "${PKR_VAR_cloudbase_msi_sha256,,}" \
  --arg qemuAgentSha256 "$WSLAB_QEMU_AGENT_MSI_SHA256" \
  '{
    schemaVersion: 1,
    os: $os,
    buildRunId: $buildRunId,
    automationSha256: $automationSha256,
    sources: {windowsIsoSha256: $windowsIsoSha256, virtioIsoSha256: $virtioIsoSha256},
    payloads: {
      cloudbaseInit: {file: "CloudbaseInitSetup.msi", sha256: $cloudbaseSha256},
      qemuGuestAgent: {file: "qemu-ga-x86_64.msi", sha256: $qemuAgentSha256}
    }
  }' >"$answer_directory/payload-manifest.json"
chmod 0600 "$answer_directory/payload-manifest.json"
python3 "$SCRIPT_DIR/Render-WindowsAnswerMedia.py" \
  --os "$os" \
  --template-directory "$WSLAB_ROOT/packer/windows" \
  --output-directory "$answer_directory"
answer_iso_name="wslab-install-${os}-${template_id}-$$.iso"
answer_volume="${iso_storage}:iso/${answer_iso_name}"
answer_iso_path="$(pvesm path "$answer_volume")"
[[ ! -e "$answer_iso_path" ]] || wslab_die "Temporary integrated ISO path already exists: $answer_iso_path"
install -d -m 0755 "$(dirname "$answer_iso_path")"

# Microsoft consumer media stores the installation tree in UDF and hides the
# El Torito images from the ISO9660 tree, so xorriso cannot safely replay it in
# place. Mount the verified source read-only, overlay only WSLABDATA files, and
# rebuild BIOS/UEFI entries from Microsoft's exact etfsboot.com and efisys.bin.
source_mount="$answer_directory/source-media"
overlay_upper="$answer_directory/overlay-upper"
overlay_work="$answer_directory/overlay-work"
overlay_mount="$answer_directory/integrated-media"
mkdir -p "$source_mount" "$overlay_upper" "$overlay_work" "$overlay_mount"
mount -o loop,ro "$iso_path" "$source_mount"
for boot_file in boot/etfsboot.com efi/microsoft/boot/efisys.bin; do
  [[ -s "$source_mount/$boot_file" ]] || wslab_die "Verified Windows source media is missing $boot_file"
done
install -m 0600 "$answer_directory/Autounattend.xml" "$overlay_upper/Autounattend.xml"
install -m 0600 "$answer_directory/bootstrap.ps1" "$overlay_upper/bootstrap.ps1"
install -m 0600 "$answer_directory/payload-manifest.json" "$overlay_upper/payload-manifest.json"
install -m 0600 "$cloudbase_media_path" "$overlay_upper/CloudbaseInitSetup.msi"
install -m 0600 "$qemu_agent_media_path" "$overlay_upper/qemu-ga-x86_64.msi"
cp -a "$answer_directory/WSLABDRIVERS" "$overlay_upper/WSLABDRIVERS"
mount -t overlay overlay -o "lowerdir=$source_mount,upperdir=$overlay_upper,workdir=$overlay_work" "$overlay_mount"
genisoimage -quiet -iso-level 3 -udf -J -joliet-long -D -N -f -allow-limited-size \
  -V WSLABDATA \
  -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 \
  -eltorito-alt-boot -e efi/microsoft/boot/efisys.bin -no-emul-boot \
  -o "$answer_iso_path" "$overlay_mount" || wslab_die "Unable to create the bootable WSLABDATA Windows media overlay"
chmod 0600 "$answer_iso_path"
umount "$overlay_mount"
overlay_mount=""
umount "$source_mount"
source_mount=""
python3 -c 'import sys,xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$answer_directory/Autounattend.xml" || wslab_die "Rendered Autounattend.xml failed final XML validation"
answer_contents="$(xorriso -indev "$answer_iso_path" -ls / 2>/dev/null)"
for required_file in Autounattend.xml bootstrap.ps1 payload-manifest.json CloudbaseInitSetup.msi qemu-ga-x86_64.msi WSLABDRIVERS; do
  grep -Fq "'$required_file'" <<<"$answer_contents" || wslab_die "Integrated WSLABDATA media is missing $required_file"
done
xorriso -indev "$answer_iso_path" -pvd_info 2>&1 | grep -Fq "Volume id    : 'WSLABDATA'" || wslab_die "Integrated media has the wrong volume label"
xorriso -indev "$answer_iso_path" -report_el_torito plain 2>&1 | grep -Eq 'El Torito boot img' || wslab_die "Integrated media lost its boot catalog"
answer_iso_sha256="$(sha256sum "$answer_iso_path" | awk '{print $1}')"
printf '%s  %s\n' "$answer_iso_sha256" "$(pvesm path "$answer_volume")" | sha256sum --check --status || wslab_die "Temporary answer ISO checksum mismatch"

mark_builder_vm() {
  local marker_checks=0 existing_name
  while ((marker_checks < 120)); do
    ((marker_checks += 1))
    if wslab_qm_exists "$template_id"; then
      existing_name="$(wslab_qm_name "$template_id")"
      if [[ "$existing_name" == "wslab-${os}" ]] && wslab_qm_has_tag "$template_id" wslab-build; then
        qm set "$template_id" --description "Packer ephemeral build VM; WSLAB-BUILD-RUN=$build_run_id" >/dev/null
        return 0
      fi
    fi
    sleep 1
  done
  wslab_log WARN "Builder VM $template_id did not become identifiable by its expected Packer name/tag within the marker timeout"
  return 1
}

packer init "$WSLAB_ROOT/packer/windows/windows.pkr.hcl"
mark_builder_vm &
builder_marker_pid="$!"
packer build \
  -var "os_type=$os" \
  -var "vm_id=$template_id" \
  -var "node=$node" \
  -var "storage_pool=$storage" \
  -var "build_bridge=$build_bridge" \
  -var "build_ipv4_address=$WSLAB_BUILD_IPV4_ADDRESS" \
  -var "build_run_id=$build_run_id" \
  -var "iso_file=$answer_volume" \
  -var "iso_sha256=$answer_iso_sha256" \
  -var "virtio_iso=$virtio_iso" \
  -var "virtio_iso_sha256=$virtio_iso_sha256" \
  "$WSLAB_ROOT/packer/windows/windows.pkr.hcl"
wait "$builder_marker_pid" || wslab_die "Builder VM ownership marker was not applied"
builder_marker_pid=""

qm config "$template_id" | grep -Eq '^template: 1$' || wslab_die "Packer completed but VM $template_id is not a template"
build_succeeded="true"
build_receipt_directory="$(wslab_report_directory "$site_file")/template-builds"
build_receipt="$build_receipt_directory/template-${os}-${template_id}.json"
mkdir -p "$build_receipt_directory"
chmod 0750 "$build_receipt_directory"
jq -n \
  --arg os "$os" \
  --argjson templateId "$template_id" \
  --arg buildRunId "$build_run_id" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg sourceWindowsIsoSha256 "${iso_sha256,,}" \
  --arg sourceVirtioIsoSha256 "${virtio_iso_sha256,,}" \
  --arg generatedMediaSha256 "$answer_iso_sha256" \
  --arg templateConfigSha256 "$(wslab_template_config_sha256 "$template_id")" \
  --arg automationSha256 "$(wslab_template_automation_sha256)" \
  '{schemaVersion:1,os:$os,templateId:$templateId,buildRunId:$buildRunId,timestamp:$timestamp,sources:{windowsIsoSha256:$sourceWindowsIsoSha256,virtioIsoSha256:$sourceVirtioIsoSha256,generatedMediaSha256:$generatedMediaSha256},templateConfigSha256:$templateConfigSha256,automationSha256:$automationSha256}' \
  >"${build_receipt}.tmp.$$"
chmod 0640 "${build_receipt}.tmp.$$"
mv -f "${build_receipt}.tmp.$$" "$build_receipt"
wslab_log INFO "Built template $template_id for $os; live clone certification is still required"
