#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
action="status"
apply="false"

usage() {
  printf 'Usage: %s --site <json> --action <activate|status> [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --action) action="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || { usage >&2; exit 2; }
[[ "$action" == "activate" || "$action" == "status" ]] || wslab_die "--action must be activate or status"
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"
definition_file="$(wslab_definition_path)"

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "$action Windows licensing on all six lab guests through QEMU Guest Agent"
  if [[ "$action" == "activate" ]]; then
    wslab_log PLAN "prompt without echo for one Server key and one Windows 11 Education key; send them only over guest-agent stdin"
  fi
  while IFS= read -r vm; do
    wslab_log PLAN "$(jq -r '.name' <<<"$vm") ($(jq -r '.id' <<<"$vm"))"
  done < <(wslab_virtual_machines "$definition_file")
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
wslab_require_proxmox
for command in base64 iconv; do wslab_require_command "$command"; done
[[ "$(hostname -s)" == "$(wslab_proxmox_node "$site_file")" ]] || wslab_die "Terraform targets a different Proxmox node"

server_key=""
client_key=""
cleanup_secrets() {
  server_key=""
  client_key=""
  unset server_key client_key
}
trap cleanup_secrets EXIT

if [[ "$action" == "activate" ]]; then
  read -r -s -p 'Windows Server product key: ' server_key
  printf '\n'
  read -r -s -p 'Windows 11 Education product key: ' client_key
  printf '\n'
  [[ "$server_key" =~ ^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$ ]] || wslab_die "The Server key has an invalid format"
  [[ "$client_key" =~ ^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$ ]] || wslab_die "The Windows 11 Education key has an invalid format"
fi

read -r -d '' activation_script <<'POWERSHELL' || true
$ErrorActionPreference = 'Stop'
$plainKey = [Console]::In.ReadToEnd().Trim()
$secureKey = $null
try {
    $activationScript = 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabWindowsActivation.ps1'
    if (-not (Test-Path -LiteralPath $activationScript -PathType Leaf)) { throw 'The activation script is missing from the template payload.' }
    if ($plainKey) {
        if ($plainKey -cnotmatch '^[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}$') { throw 'Runtime activation input has an invalid format.' }
        $secureKey = [Security.SecureString]::new()
        foreach ($keyCharacter in $plainKey.ToCharArray()) { $secureKey.AppendChar($keyCharacter) }
        $secureKey.MakeReadOnly()
        & $activationScript -Action Activate -ProductKey $secureKey -Confirm:$false | Out-Null
    }
    else {
        & $activationScript -Action Status | Out-Null
    }
}
finally {
    $plainKey = $null
    if ($secureKey) { $secureKey.Dispose() }
}
POWERSHELL
encoded_script="$(printf '%s' "$activation_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"

results='[]'
failed=0
timeout_seconds="$(jq -r '.features.guestAgentTimeoutSeconds // 900' "$site_file")"
while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  role="$(jq -r '.role' <<<"$vm")"
  product_class="Server"
  runtime_key="$server_key"
  if [[ "$role" == "client" ]]; then
    product_class="Windows11Education"
    runtime_key="$client_key"
  fi
  if [[ "$action" == "status" ]]; then runtime_key=""; fi

  machine_status="failed"
  exit_code=-1
  if wslab_qm_exists "$vmid" && wslab_qm_has_tag "$vmid" wslab; then
    wslab_wait_for_guest_agent "$vmid" "$timeout_seconds"
    result="$(printf '%s' "$runtime_key" | qm guest exec "$vmid" --pass-stdin 1 --timeout 300 -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded_script")"
    exit_code="$(jq -r '.exitcode // -1' <<<"$result")"
    if [[ "$exit_code" -eq 0 ]]; then machine_status="completed"; else ((failed += 1)); fi
  else
    ((failed += 1))
  fi
  results="$(jq \
    --argjson vmId "$vmid" \
    --arg name "$name" \
    --arg productClass "$product_class" \
    --arg status "$machine_status" \
    --argjson exitCode "$exit_code" \
    '. + [{vmId:$vmId,name:$name,productClass:$productClass,status:$status,exitCode:$exitCode}]' <<<"$results")"
  runtime_key=""
done < <(wslab_virtual_machines "$definition_file")

report_directory="$(wslab_report_directory "$site_file")"
mkdir -p "$report_directory"
report_file="$report_directory/activation-$(date -u +%Y%m%dT%H%M%SZ).json"
jq -n \
  --arg action "$action" \
  --arg status "$([[ "$failed" -eq 0 ]] && printf passed || printf failed)" \
  --argjson machines "$results" \
  '{schemaVersion:3,timestamp:(now|todate),lab:"asgard",action:$action,status:$status,machines:$machines}' >"$report_file"
chmod 0640 "$report_file"
wslab_log INFO "Redacted activation report: $report_file"
((failed == 0)) || wslab_die "$failed machines failed the requested licensing action"
