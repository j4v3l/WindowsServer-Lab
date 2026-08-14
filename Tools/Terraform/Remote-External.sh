#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
query="$(jq -c .)"

WSLAB_PROXMOX_HOST="$(jq -r '.host // empty' <<<"$query")"
WSLAB_PROXMOX_NODE="$(jq -r '.node // empty' <<<"$query")"
WSLAB_PROXMOX_SSH_USER="$(jq -r '.ssh_user // "root"' <<<"$query")"
WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH="$(jq -r '.ssh_private_key_path // empty' <<<"$query")"
WSLAB_REMOTE_OPERATION="$(jq -r '.operation // empty' <<<"$query")"
WSLAB_SITE_FILE="$(jq -r '.site_file // empty' <<<"$query")"
WSLAB_PREFLIGHT_MODE="$(jq -r '.mode // empty' <<<"$query")"
WSLAB_TEMPLATE_OS="$(jq -r '.os // empty' <<<"$query")"
export WSLAB_PROXMOX_HOST WSLAB_PROXMOX_NODE WSLAB_PROXMOX_SSH_USER WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH
export WSLAB_REMOTE_OPERATION WSLAB_SITE_FILE WSLAB_PREFLIGHT_MODE WSLAB_TEMPLATE_OS

for attempt in 1 2 3; do
  if "$SCRIPT_DIR/Remote-Run.sh"; then
    exit 0
  fi
  ((attempt < 3)) || break
  printf 'Read-only remote inspection attempt %d failed; retrying.\n' "$attempt" >&2
  sleep 5
done
exit 1
