#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
phase="full"
offline="false"

while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --phase) phase="${2:-}"; shift 2 ;;
    --offline) offline="true"; shift ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || wslab_die "Usage: $0 --site <file> --phase <infrastructure|domain|services|security|full> [--offline]"
case "$phase" in infrastructure|domain|services|security|full) ;; *) wslab_die "Unsupported phase: $phase" ;; esac

wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"
definition_file="$(wslab_definition_path)"

if [[ "$offline" == "false" ]]; then
  wslab_require_proxmox
  for command in base64 iconv; do wslab_require_command "$command"; done
fi

results_file="$(mktemp)"
trap 'rm -f "$results_file" "${results_file}.new"' EXIT
printf '[]\n' >"$results_file"

add_result() {
  local name="$1" status="$2" evidence="$3" remediation="$4" required="${5:-true}"
  jq --arg name "$name" --arg status "$status" --arg evidence "$evidence" --arg remediation "$remediation" --argjson required "$required" '. + [{name:$name,status:$status,evidence:$evidence,remediation:$remediation,required:$required}]' "$results_file" >"${results_file}.new"
  mv "${results_file}.new" "$results_file"
  case "$status" in
    pass) log_level=PASS ;;
    skipped) log_level=SKIP ;;
    *) log_level=FAIL ;;
  esac
  wslab_log "$log_level" "$name: $evidence"
}

manifest_ok="$(jq '
  . as $lab |
  (.virtualMachines | length >= 6) and
  ([.virtualMachines[] | select(.role == "primary-dc")] | length == 1) and
  ([.virtualMachines[] | select(.role == "secondary-dc")] | length == 1) and
  ([.virtualMachines[] | select(.role == "file-server")] | length == 1) and
  ([.virtualMachines[] | select(.role == "web-server")] | length == 1) and
  ([.virtualMachines[] | select(.role == "management-server")] | length == 1) and
  ([.virtualMachines[] | select(.role == "client")] | length >= 1) and
  (all(.virtualMachines[] | select(.os == "server-2025"); .nics[0].network == "windowsServers" and $lab.networks[.nics[0].network].vlanId == 90)) and
  (all(.virtualMachines[] | select(.os == "windows-11"); .nics[0].network == "windowsClients" and $lab.networks[.nics[0].network].vlanId == 100))
' "$definition_file")"
if [[ "$manifest_ok" == "true" ]]; then
  add_result manifest pass "the inventory contains all core roles and uses the required server/client networks" "" true
else
  add_result manifest fail "inventory does not contain the required core roles or network mappings" "Correct LabConfig/lab.json" true
fi

if [[ "$offline" == "false" ]]; then
  while IFS= read -r vm; do
    vmid="$(jq -r '.id' <<<"$vm")"
    name="$(jq -r '.name' <<<"$vm")"
    if ! wslab_qm_exists "$vmid"; then
      add_result "vm-${vmid}-exists" fail "$name is absent" "Run terraform -chdir=terraform apply" true
      continue
    fi
    if [[ "$(wslab_qm_name "$vmid")" != "$name" ]] || ! wslab_qm_has_tag "$vmid" wslab || ! wslab_qm_has_tag "$vmid" terraform; then
      add_result "vm-${vmid}-identity" fail "ID, name, or Terraform ownership tag mismatch" "Resolve the conflict without overwriting an unrelated VM" true
      continue
    fi
    add_result "vm-${vmid}-identity" pass "$name is Terraform-owned" "" true
    if [[ "$(qm status "$vmid" | awk '{print $2}')" != "running" ]]; then
      add_result "vm-${vmid}-running" fail "$name is not running" "Start the VM and inspect its Proxmox task log" true
    elif qm guest cmd "$vmid" ping >/dev/null 2>&1; then
      add_result "vm-${vmid}-guest-agent" pass "$name guest agent responded" "" true
    else
      add_result "vm-${vmid}-guest-agent" fail "$name guest agent did not respond" "Verify the QEMU Guest Agent service and Terraform agent setting" true
    fi
  done < <(wslab_virtual_machines "$definition_file")
else
  add_result live-infrastructure skipped "Offline validation requested" "Run again on the Proxmox node without --offline" false
fi

if [[ "$offline" == "false" && "$phase" != "infrastructure" ]]; then
  while IFS= read -r vm; do
    vmid="$(jq -r '.id' <<<"$vm")"
    name="$(jq -r '.name' <<<"$vm")"
    role="$(jq -r '.role' <<<"$vm")"
    compliance_script="& 'C:\ProgramData\WindowsServerLab\Scripts\Test-LabCompliance.ps1' -Phase '$phase' -Role '$role' | Out-Null"
    encoded_script="$(printf '%s' "$compliance_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
    if result="$(qm guest exec "$vmid" --timeout 600 -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded_script" 2>/dev/null)" && [[ "$(jq -r '.exitcode // -1' <<<"$result")" -eq 0 ]]; then
      add_result "guest-${vmid}-${phase}" pass "$name passed $phase checks" "" true
    else
      add_result "guest-${vmid}-${phase}" fail "$name failed or could not run $phase checks" "Review the guest compliance report and bootstrap log" true
    fi
  done < <(wslab_virtual_machines "$definition_file")
fi

failed="$(jq '[.[] | select(.required == true and .status != "pass")] | length' "$results_file")"
report="$(jq -n --arg phase "$phase" --argjson failed "$failed" --slurpfile results "$results_file" '{schemaVersion:3,lab:"asgard",phase:$phase,timestamp:(now|todate),passed:($failed==0),results:$results[0]}')"

if [[ "$offline" == "false" ]]; then
  report_directory="$(wslab_report_directory "$site_file")"
  mkdir -p "$report_directory"
  report_stem="$report_directory/test-${phase}-$(date -u +%Y%m%dT%H%M%SZ)"
  printf '%s\n' "$report" >"${report_stem}.json"
  tests="$(jq 'length' "$results_file")"
  failures="$(jq '[.[] | select(.required == true and .status == "fail")] | length' "$results_file")"
  skipped="$(jq '[.[] | select(.status == "skipped")] | length' "$results_file")"
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<testsuite name="WindowsServerLab.%s" tests="%s" failures="%s" skipped="%s">\n' "$phase" "$tests" "$failures" "$skipped"
    jq -r '.[] | if .status == "pass" then "  <testcase name=\"\(.name | @html)\"/>" elif .status == "skipped" then "  <testcase name=\"\(.name | @html)\"><skipped message=\"\(.evidence | @html)\"/></testcase>" else "  <testcase name=\"\(.name | @html)\"><failure message=\"\(.remediation | @html)\">\(.evidence | @html)</failure></testcase>" end' "$results_file"
    printf '</testsuite>\n'
  } >"${report_stem}.xml"
  wslab_log INFO "Validation evidence: ${report_stem}.json and ${report_stem}.xml"
else
  printf '%s\n' "$report"
fi

((failed == 0)) || exit 1
