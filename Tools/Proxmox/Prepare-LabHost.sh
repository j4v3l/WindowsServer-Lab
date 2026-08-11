#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

operator_file=""
site_file=""
artifact_file=""
packer_url=""
packer_sha256=""
virtio_url=""
virtio_sha256=""
apply="false"

usage() {
  printf 'Usage: %s --operator <json> --site <json> (--artifacts <json> | --packer-url <https-url> --packer-sha256 <sha256> --virtio-url <https-url> --virtio-sha256 <sha256>) [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --operator) operator_file="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --artifacts) artifact_file="${2:-}"; shift 2 ;;
    --packer-url) packer_url="${2:-}"; shift 2 ;;
    --packer-sha256) packer_sha256="${2:-}"; shift 2 ;;
    --virtio-url) virtio_url="${2:-}"; shift 2 ;;
    --virtio-sha256) virtio_sha256="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$operator_file" && -n "$site_file" ]] || { usage >&2; exit 2; }
wslab_require_command jq
wslab_require_command ssh
if [[ -n "$artifact_file" ]]; then
  [[ -z "$packer_url" && -z "$packer_sha256" && -z "$virtio_url" && -z "$virtio_sha256" ]] || wslab_die "Use --artifacts or individual artifact arguments, not both"
  artifact_file="$(wslab_realpath "$artifact_file")"
  [[ -r "$artifact_file" ]] || wslab_die "Build artifact manifest is not readable: $artifact_file"
  jq -e '.schemaVersion == 1 and .packer.url and .packer.sha256 and .virtio.url and .virtio.sha256' "$artifact_file" >/dev/null || wslab_die "Invalid build artifact manifest"
  packer_url="$(jq -r '.packer.url' "$artifact_file")"
  packer_sha256="$(jq -r '.packer.sha256' "$artifact_file")"
  virtio_url="$(jq -r '.virtio.url' "$artifact_file")"
  virtio_sha256="$(jq -r '.virtio.sha256' "$artifact_file")"
fi
[[ -n "$packer_url" && -n "$packer_sha256" && -n "$virtio_url" && -n "$virtio_sha256" ]] || { usage >&2; exit 2; }
[[ "$packer_url" == https://* ]] || wslab_die "--packer-url must use HTTPS"
[[ "$virtio_url" == https://* ]] || wslab_die "--virtio-url must use HTTPS"
[[ "$packer_sha256" =~ ^[A-Fa-f0-9]{64}$ ]] || wslab_die "--packer-sha256 must be a SHA-256 digest"
[[ "$virtio_sha256" =~ ^[A-Fa-f0-9]{64}$ ]] || wslab_die "--virtio-sha256 must be a SHA-256 digest"
[[ ! "$packer_sha256" =~ ^0{64}$ && ! "$virtio_sha256" =~ ^0{64}$ ]] || wslab_die "Placeholder all-zero artifact digests are not accepted"
operator_file="$(wslab_realpath "$operator_file")"
site_file="$(wslab_realpath "$site_file")"
[[ -r "$operator_file" && -r "$site_file" ]] || wslab_die "Operator and site configurations must be readable"

host="$(jq -r '.proxmoxHost' "$operator_file")"
node="$(jq -r '.proxmoxNode' "$operator_file")"
ssh_user="$(jq -r '.sshUser' "$operator_file")"
private_key="$(jq -r '.sshPrivateKeyPath' "$operator_file")"
site_node="$(jq -r '.proxmox.node' "$site_file")"
virtio_volume="$(jq -r '.proxmox.virtioIso' "$site_file")"
site_virtio_sha256="$(jq -r '.proxmox.virtioIsoSha256' "$site_file")"
guest_public_key="$(jq -r '.guestAccess.sshPublicKeyFile' "$site_file")"
guest_private_key="$(jq -r '.guestAccess.sshPrivateKeyFile' "$site_file")"
[[ "$node" == "$site_node" ]] || wslab_die "Operator node and site node do not match"
[[ "${virtio_sha256,,}" == "${site_virtio_sha256,,}" ]] || wslab_die "--virtio-sha256 must match proxmox.virtioIsoSha256 in the site configuration"
[[ "$ssh_user" == "root" ]] || wslab_die "Host preparation requires the explicitly configured root SSH account"
[[ -r "$private_key" ]] || wslab_die "SSH private key is not readable: $private_key"

ssh_options=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i "$private_key")
remote=(ssh "${ssh_options[@]}" "${ssh_user}@${host}")
remote_node="$("${remote[@]}" hostname -s)"
[[ "$remote_node" == "$node" ]] || wslab_die "Connected to $remote_node but configuration targets $node"

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "prepare $node without modifying networking, existing VMs, or storage definitions"
  wslab_log PLAN "install required Debian packages: arping ca-certificates curl jq unzip xorriso"
  wslab_log PLAN "install checksum-verified Packer only when it is absent"
  wslab_log PLAN "download checksum-verified VirtIO media only when $virtio_volume is absent"
  wslab_log PLAN "create the dedicated guest bootstrap Ed25519 keypair only when both key files are absent"
  wslab_log PLAN "write no API tokens, Windows passwords, or product keys"
  exit 0
fi

"${remote[@]}" bash -s -- \
  "$packer_url" "$packer_sha256" "$virtio_url" "$virtio_sha256" "$virtio_volume" \
  "$guest_public_key" "$guest_private_key" <<'REMOTE_SCRIPT'
set -euo pipefail
packer_url="$1"
packer_sha256="$2"
virtio_url="$3"
virtio_sha256="$4"
virtio_volume="$5"
guest_public_key="$6"
guest_private_key="$7"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends arping ca-certificates curl jq unzip xorriso

packer_archive=""
virtio_download=""
trap '[[ -z "$packer_archive" ]] || rm -f -- "$packer_archive"; [[ -z "$virtio_download" ]] || rm -f -- "$virtio_download"' EXIT
install_packer="true"
if command -v packer >/dev/null 2>&1; then
  existing_version="$(packer version | sed -nE 's/^Packer v([0-9]+\.[0-9]+).*/\1/p' | head -1)"
  existing_major="${existing_version%%.*}"
  existing_minor="${existing_version#*.}"
  if [[ -n "$existing_version" ]] && ((existing_major > 1 || (existing_major == 1 && existing_minor >= 10))); then
    install_packer="false"
  fi
fi
if [[ "$install_packer" == "true" ]]; then
  packer_archive="$(mktemp /tmp/packer.XXXXXX.zip)"
  curl --fail --location --proto '=https' --tlsv1.2 --output "$packer_archive" "$packer_url"
  printf '%s  %s\n' "$packer_sha256" "$packer_archive" | sha256sum --check --status
  unzip -p "$packer_archive" packer > /usr/local/bin/packer.new
  chmod 0755 /usr/local/bin/packer.new
  mv /usr/local/bin/packer.new /usr/local/bin/packer
fi

packer_version="$(packer version | sed -nE 's/^Packer v([0-9]+\.[0-9]+).*/\1/p' | head -1)"
[[ -n "$packer_version" ]] || { printf 'Unable to determine Packer version\n' >&2; exit 1; }
packer_major="${packer_version%%.*}"
packer_minor="${packer_version#*.}"
((packer_major > 1 || (packer_major == 1 && packer_minor >= 10))) || { printf 'Packer 1.10 or newer is required\n' >&2; exit 1; }

virtio_path="$(pvesm path "$virtio_volume")"
if [[ -e "$virtio_path" ]]; then
  printf '%s  %s\n' "$virtio_sha256" "$virtio_path" | sha256sum --check --status || {
    printf 'Existing VirtIO media checksum differs; refusing to overwrite %s\n' "$virtio_path" >&2
    exit 1
  }
else
  install -d -m 0755 "$(dirname "$virtio_path")"
  virtio_download="$(mktemp "$(dirname "$virtio_path")/.virtio-win.XXXXXX.iso")"
  curl --fail --location --proto '=https' --tlsv1.2 --output "$virtio_download" "$virtio_url"
  printf '%s  %s\n' "$virtio_sha256" "$virtio_download" | sha256sum --check --status
  chmod 0644 "$virtio_download"
  mv "$virtio_download" "$virtio_path"
  virtio_download=""
fi

if [[ -e "$guest_private_key" || -e "$guest_public_key" ]]; then
  [[ -r "$guest_private_key" && -r "$guest_public_key" ]] || {
    printf 'Only one guest key file exists; refusing to replace an incomplete keypair\n' >&2
    exit 1
  }
else
  install -d -m 0700 "$(dirname "$guest_private_key")"
  ssh-keygen -q -t ed25519 -N '' -C 'windows-server-lab-bootstrap' -f "$guest_private_key"
  chmod 0600 "$guest_private_key"
  chmod 0644 "$guest_public_key"
fi
REMOTE_SCRIPT

wslab_log PASS "$node host prerequisites prepared; rerun Inspect-RemoteHost.sh before building templates"
