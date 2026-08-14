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
  if qm agent "$template_id" ping >/dev/null 2>&1; then
    failure_probe="$(qm guest exec "$template_id" -- cmd.exe /d /c 'if exist C:\ProgramData\WindowsServerLab\seal.failed (exit /b 42) else (exit /b 0)' 2>/dev/null || true)"
    failure_exit="$(printf '%s' "$failure_probe" | jq -r '.exitcode // empty' 2>/dev/null || true)"
    if [ "$failure_exit" = 42 ]; then
      failure_json="$(qm guest exec "$template_id" -- cmd.exe /d /c 'type C:\ProgramData\WindowsServerLab\seal.failed' 2>/dev/null || true)"
      failure_message="$(printf '%s' "$failure_json" | jq -r '."out-data" // ."err-data" // "Template seal failed without readable evidence."' 2>/dev/null || true)"
      printf 'Template builder %s reported a seal failure: %s\n' "$template_id" "$failure_message" >&2
      exit 1
    fi
  fi
  elapsed="$(( $(awk '{print int($1)}' /proc/uptime) - started ))"
  if [ "$elapsed" -ge "$timeout_seconds" ]; then
    printf 'Template builder %s did not stop within %ss.\n' "$template_id" "$timeout_seconds" >&2
    exit 1
  fi
  sleep 5
done
