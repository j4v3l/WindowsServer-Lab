#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

os=""
site_file=""
evidence_mirror=""
retain_failed_canary="false"
apply="false"

usage() {
  printf 'Usage: %s --os <server-2025|server-2022|windows-11> --site <json> [--evidence-dir <path>] [--retain-failed-canary] [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --os) os="${2:-}"; shift 2 ;;
    --site) site_file="${2:-}"; shift 2 ;;
    --evidence-dir) evidence_mirror="${2:-}"; shift 2 ;;
    --retain-failed-canary) retain_failed_canary="true"; shift ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

case "$os" in server-2025|server-2022|windows-11) ;; *) usage >&2; exit 2 ;; esac
[[ -n "$site_file" ]] || { usage >&2; exit 2; }
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs asgard smoke "$site_file"

template_id="$(jq -r --arg os "$os" '.proxmox.templates[$os]' "$site_file")"
canary_id="$(jq -r '.templateCertification.vmId' "$site_file")"
canary_address="$(jq -r '.templateCertification.address' "$site_file")"
timeout_seconds="$(jq -r '.templateCertification.timeoutSeconds' "$site_file")"
bridge="$(jq -r '.templateBuildNetwork.bridge' "$site_file")"
prefix_length="$(jq -r '.templateBuildNetwork.prefixLength' "$site_file")"
gateway="$(jq -r '.templateBuildNetwork.gateway' "$site_file")"
dns_servers="$(jq -r '.templateBuildNetwork.dnsServers | join(" ")' "$site_file")"
canonical_evidence_dir="$(wslab_template_certification_directory "$site_file")"
evidence_file="$(wslab_template_certification_file "$site_file" "$os" "$template_id")"
junit_file="$canonical_evidence_dir/template-${os}-${template_id}.junit.xml"

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "certify template $template_id for $os with two sequential clones using VM ID $canary_id"
  wslab_log PLAN "use $canary_address/$prefix_length on $bridge and wait up to ${timeout_seconds}s per canary"
  wslab_log PLAN "verify Cloudbase-Init, QEMU Guest Agent, unique identity, sealed credentials, and build-only WinRM cleanup"
  wslab_log PLAN "write canonical JSON and JUnit evidence under $canonical_evidence_dir"
  [[ -z "$evidence_mirror" ]] || wslab_log PLAN "copy redacted evidence to $evidence_mirror"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
wslab_require_proxmox
for command in arping base64 iconv python3 sha256sum; do wslab_require_command "$command"; done
[[ "$(hostname -s)" == "$(jq -r '.proxmox.node' "$site_file")" ]] || wslab_die "The site configuration targets a different Proxmox node"
[[ -d "/sys/class/net/$bridge" ]] || wslab_die "Certification bridge does not exist: $bridge"
qm config "$template_id" | grep -Eq '^template: 1$' || wslab_die "Template $template_id for $os is missing or not a Proxmox template"
if wslab_qm_exists "$canary_id"; then wslab_die "Certification VM ID $canary_id is already in use"; fi

mkdir -p "$canonical_evidence_dir"
chmod 0750 "$canonical_evidence_dir"
if [[ -n "$evidence_mirror" ]]; then
  mkdir -p "$evidence_mirror"
  evidence_mirror="$(wslab_realpath "$evidence_mirror")"
fi

run_id="cert-${os}-${template_id}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
run_tag="wslab-cert-$(date -u +%Y%m%d%H%M%S)-$$"
node="$(hostname -s)"
pve_version="$(pveversion | head -n 1)"
config_sha256="$(wslab_template_config_sha256 "$template_id")"
build_receipt="$(wslab_report_directory "$site_file")/template-builds/template-${os}-${template_id}.json"
zero_sha="$(printf '0%.0s' {1..64})"
build_run_id="unknown"
windows_iso_sha256="$zero_sha"
virtio_iso_sha256="$zero_sha"
generated_media_sha256="$zero_sha"
cloudbase_sha256="$zero_sha"
qemu_agent_sha256="$zero_sha"
automation_sha256="$zero_sha"
canaries='[]'
certification_succeeded="false"
active_canary="false"
failure_message="Certification did not complete."

redact_text() {
  sed -E 's/\b[A-Z0-9]{5}(-[A-Z0-9]{5}){4}\b/[REDACTED-PRODUCT-KEY]/g' <<<"$1"
}

write_evidence() {
  local status="$1"
  local error_text="$2"
  local timestamp temporary_file failure_count escaped_error
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  temporary_file="${evidence_file}.tmp.$$"
  jq -n \
    --arg status "$status" \
    --arg timestamp "$timestamp" \
    --arg error "$error_text" \
    --argjson templateId "$template_id" \
    --arg os "$os" \
    --arg node "$node" \
    --arg pveVersion "$pve_version" \
    --arg configSha256 "$config_sha256" \
    --arg buildRunId "$build_run_id" \
    --arg windowsIsoSha256 "$windows_iso_sha256" \
    --arg virtioIsoSha256 "$virtio_iso_sha256" \
    --arg generatedMediaSha256 "$generated_media_sha256" \
    --arg cloudbaseInitSha256 "$cloudbase_sha256" \
    --arg qemuGuestAgentSha256 "$qemu_agent_sha256" \
    --arg automationSha256 "$automation_sha256" \
    --argjson canaries "$canaries" '
      {
        schemaVersion: 1,
        status: $status,
        timestamp: $timestamp,
        template: {
          id: $templateId,
          os: $os,
          node: $node,
          pveVersion: $pveVersion,
          configSha256: $configSha256,
          buildRunId: $buildRunId,
          automationSha256: $automationSha256,
          sources: {windowsIsoSha256: $windowsIsoSha256, virtioIsoSha256: $virtioIsoSha256, generatedMediaSha256: $generatedMediaSha256},
          payloads: {cloudbaseInitSha256: $cloudbaseInitSha256, qemuGuestAgentSha256: $qemuGuestAgentSha256}
        },
        canaries: $canaries
      } + (if $error == "" then {} else {error: $error} end)
    ' >"$temporary_file"
  chmod 0640 "$temporary_file"
  mv -f "$temporary_file" "$evidence_file"

  failure_count=0
  [[ "$status" == "passed" ]] || failure_count=1
  escaped_error="$(python3 -c 'import html,sys; print(html.escape(sys.stdin.read()), end="")' <<<"$error_text")"
  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '<testsuite name="WindowsServerLab.TemplateCertification" tests="1" failures="%s">\n' "$failure_count"
    printf '  <testcase classname="template.%s" name="template-%s">' "$os" "$template_id"
    if [[ "$status" != "passed" ]]; then printf '<failure message="template certification failed">%s</failure>' "$escaped_error"; fi
    printf '%s\n' '</testcase>'
    printf '%s\n' '</testsuite>'
  } >"$junit_file"
  chmod 0640 "$junit_file"
  if [[ -n "$evidence_mirror" && "$evidence_mirror" != "$canonical_evidence_dir" ]]; then
    install -m 0640 "$evidence_file" "$evidence_mirror/$(basename "$evidence_file")"
    install -m 0640 "$junit_file" "$evidence_mirror/$(basename "$junit_file")"
  fi
}

cleanup_canary() {
  local force="$1"
  if ! wslab_qm_exists "$canary_id"; then active_canary="false"; return 0; fi
  if ! qm config "$canary_id" 2>/dev/null | grep -Fq "WSLAB-CERT-RUN=$run_id"; then
    wslab_log WARN "Certification VM $canary_id lost its run marker; refusing automatic cleanup"
    return 0
  fi
  if [[ "$force" == "false" && "$retain_failed_canary" == "true" ]]; then
    wslab_log WARN "Retaining failed canary $canary_id for diagnostics"
    return 0
  fi
  qm stop "$canary_id" --skiplock 1 >/dev/null 2>&1 || true
  qm unlock "$canary_id" >/dev/null 2>&1 || true
  qm destroy "$canary_id" --purge 1 --destroy-unreferenced-disks 1 >/dev/null
  active_canary="false"
}

on_exit() {
  local exit_status="$?"
  if [[ "$certification_succeeded" == "true" ]]; then
    cleanup_canary true || true
    write_evidence passed ""
    wslab_log PASS "Template $template_id for $os passed live clone certification"
  else
    if [[ "$active_canary" == "true" ]]; then cleanup_canary false || true; fi
    failure_message="$(redact_text "$failure_message")"
    write_evidence failed "$failure_message"
    wslab_log FAIL "$failure_message"
  fi
  return "$exit_status"
}
trap on_exit EXIT
trap '[[ "$failure_message" != "Certification did not complete." ]] || failure_message="Certification failed during line $LINENO."' ERR

guest_exec_powershell() {
  local vmid="$1"
  local script="$2"
  local encoded result exit_code
  encoded="$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
  if ! result="$(qm guest exec "$vmid" --timeout 180 -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded" 2>&1)"; then
    return 1
  fi
  jq -e 'type == "object" and has("exitcode")' >/dev/null 2>&1 <<<"$result" || return 1
  exit_code="$(jq -r '.exitcode // -1' <<<"$result")"
  [[ "$exit_code" -eq 0 ]] || { failure_message="Canary guest inspection exited with code $exit_code."; return 1; }
  jq -r '."out-data" // empty' <<<"$result" | tr -d '\r'
}

read -r -d '' inspection_script <<'POWERSHELL' || true
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\WindowsServerLab'
$templateManifestPath = Join-Path $root 'TemplateBuild.json'
if (-not (Test-Path -LiteralPath $templateManifestPath -PathType Leaf)) { throw 'TemplateBuild.json is missing.' }
$manifest = Get-Content -LiteralPath $templateManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$qemuService = Get-CimInstance Win32_Service -Filter "Name='QEMU-GA'" -ErrorAction Stop
$cloudbaseService = Get-CimInstance Win32_Service -Filter "Name='cloudbase-init'" -ErrorAction Stop
$administrator = Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' } | Select-Object -First 1
if (-not $administrator) { throw 'The built-in administrator account was not found.' }
$machineSid = $administrator.SID.Value -replace '-500$', ''
$machineGuid = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid
$httpsListeners = @(if (Test-Path -LiteralPath WSMan:\localhost\Listener) {
    Get-ChildItem WSMan:\localhost\Listener -ErrorAction Stop | Where-Object { $_.Keys -contains 'Transport=HTTPS' }
})
$buildCertificates = @(Get-ChildItem Cert:\LocalMachine\My -ErrorAction Stop | Where-Object Subject -eq 'CN=WSLAB-BUILD')
$winRmService = Get-CimInstance Win32_Service -Filter "Name='WinRM'" -ErrorAction Stop
$winRmRegistry = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Service' -ErrorAction Stop
$winRmBasic = [System.Convert]::ToBoolean($winRmRegistry.auth_basic)
$winRmUnencrypted = [System.Convert]::ToBoolean($winRmRegistry.allow_unencrypted)
$autoLogon = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop
$autoAdminValue = if ($autoLogon.PSObject.Properties.Name -contains 'AutoAdminLogon') { [string]$autoLogon.AutoAdminLogon } else { '' }
$defaultPasswordValue = if ($autoLogon.PSObject.Properties.Name -contains 'DefaultPassword') { [string]$autoLogon.DefaultPassword } else { '' }
$cachedAnswers = @(
    "$env:SystemRoot\Panther\Unattend.xml",
    "$env:SystemRoot\Panther\Unattend\Unattend.xml",
    "$env:SystemRoot\System32\Sysprep\unattend.xml"
)
$ipv4 = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress)
$operatingSystem = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
$imageState = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -Name ImageState -ErrorAction Stop).ImageState
$cloudbaseConfig = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf'
$cloudbaseUnattend = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml'
$cloudbaseLog = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log'
$firstBootCleanupPath = Join-Path $root 'first-boot-cleanup.ps1'
$firstBootCleanupCompletePath = Join-Path $root 'first-boot-cleanup.complete'
$firstBootCleanupComplete = if (Test-Path -LiteralPath $firstBootCleanupCompletePath -PathType Leaf) {
    (Get-Content -LiteralPath $firstBootCleanupCompletePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop).status -eq 'complete'
} else { $false }
$result = [ordered]@{
    hostname = $env:COMPUTERNAME
    machineSid = $machineSid
    machineGuid = $machineGuid
    operatingSystem = [string]$operatingSystem.Caption
    imageState = [string]$imageState
    ipv4 = $ipv4
    qemuAgentRunning = ($qemuService.State -eq 'Running')
    qemuAgentAutomatic = ($qemuService.StartMode -eq 'Auto')
    cloudbaseAutomatic = ($cloudbaseService.StartMode -eq 'Auto')
    cloudbaseConfigDrive = ((Get-Content -LiteralPath $cloudbaseConfig -Raw -ErrorAction Stop) -match 'ConfigDriveService')
    cloudbaseSecretsAbsent = ((Get-Content -LiteralPath $cloudbaseUnattend -Raw -ErrorAction Stop) -notmatch '(?i)<(AutoLogon|UserAccounts|DefaultPassword|PlainText)>')
    cloudbaseLogPresent = (Test-Path -LiteralPath $cloudbaseLog -PathType Leaf)
    winRmClean = ($winRmService.StartMode -eq 'Disabled' -and -not $winRmBasic -and -not $winRmUnencrypted -and $httpsListeners.Count -eq 0)
    buildCertificateAbsent = ($buildCertificates.Count -eq 0)
    buildFirewallAbsent = (-not [bool](Get-NetFirewallRule -Name 'WSLAB-WinRM-HTTPS' -ErrorAction SilentlyContinue))
    autoLogonClean = ($autoAdminValue -ne '1' -and [string]::IsNullOrEmpty($defaultPasswordValue))
    cachedAnswersAbsent = (@($cachedAnswers | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 0)
    sealScriptAbsent = (-not (Test-Path -LiteralPath "$root\seal-template.ps1"))
    firstBootCleanupComplete = $firstBootCleanupComplete
    firstBootCleanupScriptAbsent = (-not (Test-Path -LiteralPath $firstBootCleanupPath))
    firstBootCleanupTaskAbsent = (-not [bool](Get-ScheduledTask -TaskName 'WindowsServerLab-FirstBootCleanup' -ErrorAction SilentlyContinue))
    builtInAdministratorDisabled = (-not $administrator.Enabled)
    manifest = $manifest
}
$result | ConvertTo-Json -Depth 10 -Compress
POWERSHELL

run_canary() {
  local sequence="$1"
  local suffix hostname guest_output guest_json check_json canary_json inspection_deadline last_failed_checks
  suffix="$(if [[ "$sequence" -eq 1 ]]; then printf A; else printf B; fi)"
  case "$os" in
    server-2025) hostname="WSLAB-S25-$suffix" ;;
    server-2022) hostname="WSLAB-S22-$suffix" ;;
    windows-11) hostname="WSLAB-W11-$suffix" ;;
  esac

  if arping -D -c 3 -w 4 -I "$bridge" "$canary_address" >/dev/null 2>&1; then
    failure_message="Certification address $canary_address answered ARP."
    return 1
  fi
  if wslab_qm_exists "$canary_id"; then failure_message="Certification VM ID $canary_id became occupied."; return 1; fi

  wslab_log INFO "Creating certification canary $sequence/2 as VM $canary_id ($hostname)"
  qm clone "$template_id" "$canary_id" --name "$hostname" --full 0
  active_canary="true"
  qm set "$canary_id" \
    --description "WSLAB-CERT-RUN=$run_id" \
    --tags "wslab;wslab-certification;$run_tag" \
    --cores 2 \
    --memory 4096 \
    --balloon 3072 \
    --agent 'enabled=1' \
    --net0 "virtio,bridge=${bridge},firewall=1" \
    --citype configdrive2 \
    --ide2 "$(jq -r '.proxmox.vmStorage' "$site_file"):cloudinit" \
    --ipconfig0 "ip=${canary_address}/${prefix_length},gw=${gateway}" \
    --nameserver "$dns_servers" >/dev/null
  qm cloudinit update "$canary_id" >/dev/null
  qm start "$canary_id"
  wslab_wait_for_guest_agent "$canary_id" "$timeout_seconds"

  # Cloudbase-Init and the first-boot cleanup task have their own bounded
  # windows (20 minutes for cleanup).  Use the site-configured certification
  # timeout for inspection as well so a slow Windows 11 first boot is not
  # misclassified as a failed template after a fixed ten-minute slice.
  inspection_deadline="$(( $(awk '{print int($1)}' /proc/uptime) + timeout_seconds ))"
  last_failed_checks='guest execution not yet stable'
  check_json='{}'
  while (( $(awk '{print int($1)}' /proc/uptime) < inspection_deadline )); do
    if ! guest_output="$(guest_exec_powershell "$canary_id" "$inspection_script")"; then
      last_failed_checks='QEMU guest execution unavailable during first-boot specialization'
      sleep 5
      continue
    fi
    guest_json="$(tail -n 1 <<<"$guest_output")"
    if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$guest_json"; then
      last_failed_checks='guest inspection returned invalid JSON'
      sleep 5
      continue
    fi

    check_json="$(jq -n \
      --arg expectedHostname "$hostname" \
      --arg expectedAddress "$canary_address" \
      --arg expectedOs "$os" \
      --argjson guest "$guest_json" '
      {
        hostnameApplied: (($guest.hostname | ascii_upcase) == ($expectedHostname | ascii_upcase)),
        networkApplied: (($guest.ipv4 | index($expectedAddress)) != null),
        qemuAgent: ($guest.qemuAgentRunning and $guest.qemuAgentAutomatic),
        cloudbaseInit: ($guest.cloudbaseAutomatic and $guest.cloudbaseConfigDrive and $guest.cloudbaseLogPresent),
        cloudbaseSecretsRemoved: $guest.cloudbaseSecretsAbsent,
        winRmBuildAccessRemoved: $guest.winRmClean,
        buildCertificateRemoved: $guest.buildCertificateAbsent,
        buildFirewallRemoved: $guest.buildFirewallAbsent,
        autoLogonRemoved: $guest.autoLogonClean,
        cachedAnswerFilesRemoved: $guest.cachedAnswersAbsent,
        sealScriptRemoved: $guest.sealScriptAbsent,
        firstBootCleanupCompleted: ($guest.firstBootCleanupComplete and $guest.firstBootCleanupScriptAbsent and $guest.firstBootCleanupTaskAbsent),
        builtInAdministratorDisabled: $guest.builtInAdministratorDisabled,
        imageGeneralized: ($guest.imageState == "IMAGE_STATE_COMPLETE"),
        manifestMatchesOs: ($guest.manifest.schemaVersion == 1 and $guest.manifest.os == $expectedOs),
        editionMatches: (
          if $expectedOs == "windows-11" then $guest.operatingSystem == "Microsoft Windows 11 Education"
          elif $expectedOs == "server-2025" then ($guest.operatingSystem | test("Windows Server 2025"))
          else ($guest.operatingSystem | test("Windows Server 2022")) end
        )
      }
    ')"
    if jq -e 'all(.[]; . == true)' >/dev/null <<<"$check_json"; then
      break
    fi
    last_failed_checks="$(jq -r 'to_entries | map(select(.value == false) | .key) | join(", ")' <<<"$check_json")"
    sleep 5
  done
  if ! jq -e 'length > 0 and all(.[]; . == true)' >/dev/null <<<"$check_json"; then
    failure_message="Canary $sequence did not become certification-ready: $last_failed_checks"
    return 1
  fi

  if [[ "$sequence" -eq 1 ]]; then
    build_run_id="$(jq -r '.manifest.buildRunId' <<<"$guest_json")"
    windows_iso_sha256="$(jq -r '.manifest.sources.windowsIsoSha256' <<<"$guest_json")"
    virtio_iso_sha256="$(jq -r '.manifest.sources.virtioIsoSha256' <<<"$guest_json")"
    cloudbase_sha256="$(jq -r '.manifest.payloads.cloudbaseInit.sha256' <<<"$guest_json")"
    qemu_agent_sha256="$(jq -r '.manifest.payloads.qemuGuestAgent.sha256' <<<"$guest_json")"
    automation_sha256="$(jq -r '.manifest.automationSha256' <<<"$guest_json")"
    [[ -r "$build_receipt" ]] || { failure_message="Build receipt is missing for template $template_id."; return 1; }
    jq -e \
      --arg os "$os" \
      --argjson templateId "$template_id" \
      --arg buildRunId "$build_run_id" \
      --arg configSha256 "$config_sha256" \
      --arg windowsIsoSha256 "$windows_iso_sha256" \
      --arg virtioIsoSha256 "$virtio_iso_sha256" \
      --arg automationSha256 "$automation_sha256" \
      --arg currentAutomationSha256 "$(wslab_template_automation_sha256)" '
        .schemaVersion == 1 and
        .os == $os and
        .templateId == $templateId and
        .buildRunId == $buildRunId and
        .templateConfigSha256 == $configSha256 and
        .sources.windowsIsoSha256 == $windowsIsoSha256 and
        .sources.virtioIsoSha256 == $virtioIsoSha256 and
        .automationSha256 == $automationSha256 and
        $automationSha256 == $currentAutomationSha256 and
        (.sources.generatedMediaSha256 | test("^[A-Fa-f0-9]{64}$"))
      ' >/dev/null "$build_receipt" || { failure_message="Build receipt does not match template $template_id or its embedded manifest."; return 1; }
    generated_media_sha256="$(jq -r '.sources.generatedMediaSha256' "$build_receipt")"
  else
    jq -e \
      --arg buildRunId "$build_run_id" \
      --arg windowsIsoSha256 "$windows_iso_sha256" \
      --arg virtioIsoSha256 "$virtio_iso_sha256" \
      --arg automationSha256 "$automation_sha256" '
        .manifest.buildRunId == $buildRunId and
        .manifest.sources.windowsIsoSha256 == $windowsIsoSha256 and
        .manifest.sources.virtioIsoSha256 == $virtioIsoSha256 and
        .manifest.automationSha256 == $automationSha256
      ' >/dev/null <<<"$guest_json" || { failure_message="Canary manifests differ between clone runs."; return 1; }
  fi

  canary_json="$(jq -n \
    --argjson sequence "$sequence" \
    --argjson vmId "$canary_id" \
    --arg hostname "$hostname" \
    --arg machineSid "$(jq -r '.machineSid' <<<"$guest_json")" \
    --arg machineGuid "$(jq -r '.machineGuid' <<<"$guest_json")" \
    --argjson checks "$check_json" \
    '{sequence:$sequence,vmId:$vmId,hostname:$hostname,status:"passed",machineSid:$machineSid,machineGuid:$machineGuid,checks:$checks}')"
  canaries="$(jq --argjson canary "$canary_json" '. + [$canary]' <<<"$canaries")"
  cleanup_canary true
}

run_canary 1
run_canary 2
jq -e '.[0].machineSid != .[1].machineSid and .[0].machineGuid != .[1].machineGuid' >/dev/null <<<"$canaries" || {
  failure_message='The two fresh clones did not receive unique machine identities.'
  exit 1
}

certification_succeeded="true"
