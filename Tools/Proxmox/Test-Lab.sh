#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

demo=""
profile="smoke"
site_file=""
phase="full"
offline="false"

while (($#)); do
  case "$1" in
    --demo) demo="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --phase) phase="${2:-}"; shift 2 ;;
    --offline) offline="true"; shift ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$demo" && -n "$site_file" ]] || wslab_die "Usage: $0 --demo <name> --profile <smoke|core|full> --site <file> --phase <infrastructure|domain|services|security|full> [--offline]"
case "$phase" in infrastructure|domain|services|security|full) ;; *) wslab_die "Unsupported phase: $phase" ;; esac

wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$demo" "$profile" "$site_file"
definition_file="$(wslab_definition_path "$demo")"

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
  wslab_log "$([[ "$status" == "pass" ]] && printf PASS || printf FAIL)" "$name: $evidence"
}

case "$profile" in
  smoke) expected_count=6 ;;
  core) expected_count=7 ;;
  full) expected_count=30 ;;
esac
actual_count="$(jq --arg profile "$profile" '[.virtualMachines[] | select(.profiles | index($profile))] | length' "$definition_file")"
if [[ "$actual_count" -eq "$expected_count" ]]; then
  add_result "manifest-count" pass "$actual_count VMs selected" "" true
else
  add_result "manifest-count" fail "Expected $expected_count, found $actual_count" "Correct the canonical demo manifest" true
fi

if [[ "$offline" == "false" ]]; then
  while IFS= read -r vm; do
    vmid="$(jq -r '.id' <<<"$vm")"
    name="$(jq -r '.name' <<<"$vm")"
    if ! wslab_qm_exists "$vmid"; then
      add_result "vm-${vmid}-exists" fail "$name is absent" "Run Deploy-Lab.sh --apply" true
      continue
    fi
    if [[ "$(wslab_qm_name "$vmid")" != "$name" ]] || ! wslab_qm_has_tag "$vmid" wslab; then
      add_result "vm-${vmid}-identity" fail "ID, name, or ownership tag mismatch" "Resolve the VM ID conflict; do not overwrite the existing VM" true
      continue
    fi
    add_result "vm-${vmid}-identity" pass "$name is owned by WindowsServerLab" "" true

    if [[ "$(qm status "$vmid" | awk '{print $2}')" != "running" ]]; then
      add_result "vm-${vmid}-running" fail "$name is not running" "Start the VM and inspect its task log" true
    elif qm guest cmd "$vmid" ping >/dev/null 2>&1; then
      add_result "vm-${vmid}-guest-agent" pass "$name guest agent responded" "" true
    else
      add_result "vm-${vmid}-guest-agent" fail "$name guest agent did not respond" "Verify the QEMU Guest Agent service and VM agent setting" true
    fi
  done < <(wslab_profile_vms "$definition_file" "$profile")
else
  add_result "live-infrastructure" skipped "Offline validation requested" "Run again on a Proxmox node without --offline" false
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
      add_result "guest-${vmid}-${phase}" fail "$name failed or could not run $phase checks through QEMU Guest Agent" "Review the guest compliance report and bootstrap log" true
    fi
  done < <(wslab_profile_vms "$definition_file" "$profile")
fi

failed="$(jq '[.[] | select(.required == true and .status != "pass")] | length' "$results_file")"
report="$(jq -n --arg demo "$demo" --arg profile "$profile" --arg phase "$phase" --argjson failed "$failed" --slurpfile results "$results_file" '{schemaVersion:2,demo:$demo,profile:$profile,phase:$phase,timestamp:(now|todate),passed:($failed==0),results:$results[0]}')"

report_directory="$(wslab_report_directory "$site_file")"
if [[ "$offline" == "false" ]]; then
  mkdir -p "$report_directory"
  report_stem="$report_directory/test-${demo}-${profile}-${phase}-$(date -u +%Y%m%dT%H%M%SZ)"
  report_file="${report_stem}.json"
  junit_file="${report_stem}.xml"
  printf '%s\n' "$report" >"$report_file"
  tests="$(jq 'length' "$results_file")"
  failures="$(jq '[.[] | select(.required == true and .status == "fail")] | length' "$results_file")"
  skipped="$(jq '[.[] | select(.status == "skipped")] | length' "$results_file")"
  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<testsuite name="WindowsServerLab.%s.%s.%s" tests="%s" failures="%s" skipped="%s">\n' "$demo" "$profile" "$phase" "$tests" "$failures" "$skipped"
    jq -r '.[] | if .status == "pass" then "  <testcase name=\"\(.name | @html)\"/>" elif .status == "skipped" then "  <testcase name=\"\(.name | @html)\"><skipped message=\"\(.evidence | @html)\"/></testcase>" else "  <testcase name=\"\(.name | @html)\"><failure message=\"\(.remediation | @html)\">\(.evidence | @html)</failure></testcase>" end' "$results_file"
    printf '</testsuite>\n'
  } >"$junit_file"
  wslab_log INFO "Validation evidence: $report_file and $junit_file"
else
  printf '%s\n' "$report"
fi

((failed == 0)) || exit 1
