#!/usr/bin/env sh

set -eu

template_id="${WSLAB_TEMPLATE_ID:?WSLAB_TEMPLATE_ID is required}"
timeout_seconds="${WSLAB_SHUTDOWN_TIMEOUT_SECONDS:-1800}"
case "$template_id" in *[!0-9]*|'') printf 'Invalid template ID.\n' >&2; exit 2 ;; esac
case "$timeout_seconds" in *[!0-9]*|'') printf 'Invalid shutdown timeout.\n' >&2; exit 2 ;; esac

started="$(awk '{print int($1)}' /proc/uptime)"
while :; do
  vm_state="$(qm status "$template_id" 2>/dev/null | awk '{print $2}')"
  if [ "$vm_state" = stopped ]; then
    printf 'Template builder %s completed Sysprep shutdown.\n' "$template_id"
    exit 0
  fi
  elapsed="$(( $(awk '{print int($1)}' /proc/uptime) - started ))"
  if [ "$elapsed" -ge "$timeout_seconds" ]; then
    printf 'Template builder %s did not stop within %ss.\n' "$template_id" "$timeout_seconds" >&2
    exit 1
  fi
  sleep 5
done
