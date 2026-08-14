#!/usr/bin/env bash

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Tools/Proxmox/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

site_file=""
secrets_file=""
apply="false"

usage() {
  printf 'Usage: %s --site <json> [--secrets <json>] [--apply]\n' "$0"
}

while (($#)); do
  case "$1" in
    --site) site_file="${2:-}"; shift 2 ;;
    --secrets) secrets_file="${2:-}"; shift 2 ;;
    --apply) apply="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) wslab_die "Unknown argument: $1" ;;
  esac
done

[[ -n "$site_file" ]] || { usage >&2; exit 2; }
wslab_require_command jq
site_file="$(wslab_realpath "$site_file")"
wslab_validate_inputs "$site_file"
definition_file="$(wslab_definition_path)"
domain_name="$(jq -r '.domain.dnsName' "$definition_file")"
netbios_name="$(jq -r '.domain.netbiosName' "$definition_file")"
timeout_seconds="$(jq -r '.features.guestAgentTimeoutSeconds // 1800' "$site_file")"

payloads=(
  "LabConfig/lab.json|C:\ProgramData\WindowsServerLab\LabConfig\lab.json"
  "LabConfig/policies/access-controls.json|C:\ProgramData\WindowsServerLab\LabConfig\policies\access-controls.json"
  "Scripts/WindowsServerLab/WindowsServerLab.psd1|C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psd1"
  "Scripts/WindowsServerLab/WindowsServerLab.psm1|C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psm1"
  "Scripts/Initialize-LabDataDisks.ps1|C:\ProgramData\WindowsServerLab\Scripts\Initialize-LabDataDisks.ps1"
  "Scripts/Invoke-LabBootstrap.ps1|C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabBootstrap.ps1"
  "Scripts/Enable-LabEventForwarding.ps1|C:\ProgramData\WindowsServerLab\Scripts\Enable-LabEventForwarding.ps1"
  "Scripts/Enable-LabPowerShellRemoting.ps1|C:\ProgramData\WindowsServerLab\Scripts\Enable-LabPowerShellRemoting.ps1"
  "Scripts/Set-LabDomainPolicy.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabDomainPolicy.ps1"
  "Scripts/Set-LabGroupPolicyRefresh.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabGroupPolicyRefresh.ps1"
  "Scripts/Set-LabAccessControl.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1"
  "Scripts/Set-LabPrintPolicy.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabPrintPolicy.ps1"
  "Scripts/Set-LabFileSharePolicy.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1"
  "Scripts/Set-LabSharedFolder.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabSharedFolder.ps1"
  "Scripts/New-LabAsgardBranding.ps1|C:\ProgramData\WindowsServerLab\Scripts\New-LabAsgardBranding.ps1"
  "Scripts/Set-LabSecurityBaseline.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabSecurityBaseline.ps1"
  "Scripts/Set-LabClientSecurityBaseline.ps1|C:\ProgramData\WindowsServerLab\Scripts\Set-LabClientSecurityBaseline.ps1"
  "Scripts/Test-LabCompliance.ps1|C:\ProgramData\WindowsServerLab\Scripts\Test-LabCompliance.ps1"
)

if [[ "$apply" == "false" ]]; then
  wslab_log PLAN "synchronize ${#payloads[@]} checksum-verified, non-secret files to all six lab guests through QEMU Guest Agent"
  if [[ -n "$secrets_file" ]]; then
    wslab_log PLAN "read domain-administrator, DSRM, and initial lab-user passwords from the runtime-only mode-0600 JSON file"
  else
    wslab_log PLAN "prompt without echo for domain-administrator, DSRM, and initial lab-user passwords"
  fi
  wslab_log PLAN "configure AD/DNS/DHCP, replica DC, member joins, IIS, WEF, LAPS, access GPOs, print/file policy, and background GPO refresh"
  wslab_log PLAN "send secrets only over guest-agent stdin and retain none in files, arguments, logs, or evidence"
  exit 0
fi

[[ "$(id -u)" -eq 0 ]] || wslab_die "--apply must run as root on a Proxmox VE node"
wslab_require_proxmox
for command in base64 iconv sha256sum; do wslab_require_command "$command"; done
wslab_require_command flock
[[ "$(hostname -s)" == "$(wslab_proxmox_node "$site_file")" ]] || wslab_die "Terraform targets a different Proxmox node"
exec 9>/run/lock/windows-server-lab-configure.lock
flock 9

domain_admin_password=""
dsrm_password=""
lab_user_password=""
cleanup_secrets() {
  domain_admin_password=""
  dsrm_password=""
  lab_user_password=""
  unset domain_admin_password dsrm_password lab_user_password
}
trap cleanup_secrets EXIT

if [[ -n "$secrets_file" ]]; then
  secrets_file="$(wslab_realpath "$secrets_file")"
  [[ -r "$secrets_file" ]] || wslab_die "Guest secrets file is not readable: $secrets_file"
  secrets_mode="$(stat -c '%a' "$secrets_file")"
  (( (8#$secrets_mode & 077) == 0 )) || wslab_die "Guest secrets file must not be readable by group or other users"
  jq -e '
    .schemaVersion == 1 and
    (.domainAdministratorPassword | strings | length >= 14) and
    (.dsrmPassword | strings | length >= 14) and
    (.initialLabUserPassword | strings | length >= 14) and
    all([.domainAdministratorPassword, .dsrmPassword, .initialLabUserPassword][]; startswith("REPLACE-") | not)
  ' "$secrets_file" >/dev/null || wslab_die "Guest secrets file is invalid"
  domain_admin_password="$(jq -r '.domainAdministratorPassword' "$secrets_file")"
  dsrm_password="$(jq -r '.dsrmPassword' "$secrets_file")"
  lab_user_password="$(jq -r '.initialLabUserPassword' "$secrets_file")"
else
  [[ -t 0 ]] || wslab_die "Non-interactive guest configuration requires --secrets <mode-0600-json>"
  read -r -s -p "Password for $netbios_name\Administrator (used to establish the new forest): " domain_admin_password
  printf '\n'
  read -r -s -p 'DSRM recovery password: ' dsrm_password
  printf '\n'
  read -r -s -p 'Initial lab-user password (change required at first logon): ' lab_user_password
  printf '\n'
fi
for secret_value in "$domain_admin_password" "$dsrm_password" "$lab_user_password"; do
  [[ ${#secret_value} -ge 14 ]] || wslab_die "Each runtime password must contain at least 14 characters"
  [[ "$secret_value" != *$'\n'* && "$secret_value" != *$'\r'* ]] || wslab_die "Runtime passwords must be a single line"
done
secret_value=""

qga_exec() {
  local vmid="$1" script="$2" stdin_value="${3-}" encoded result exit_code started elapsed transport_warned="false"
  encoded="$(printf '%s' "$script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
  started="$(awk '{print int($1)}' /proc/uptime)"
  while true; do
    result=""
    if [[ -n "$stdin_value" ]]; then
      if result="$(printf '%s' "$stdin_value" | qm guest exec "$vmid" --pass-stdin 1 --timeout "$timeout_seconds" -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded" 2>/dev/null)"; then
        break
      fi
    elif result="$(qm guest exec "$vmid" --timeout "$timeout_seconds" -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded" 2>/dev/null)"; then
      break
    fi

    elapsed="$(( $(awk '{print int($1)}' /proc/uptime) - started ))"
    ((elapsed < timeout_seconds)) || wslab_die "Guest-agent transport for VM $vmid did not recover within ${timeout_seconds}s"
    if [[ "$transport_warned" == "false" ]]; then
      wslab_log WARN "Guest-agent transport for VM $vmid is temporarily unavailable; waiting for recovery"
      transport_warned="true"
    fi
    sleep 5
  done

  jq -e 'type == "object" and (.exitcode | type == "number")' >/dev/null <<<"$result" || wslab_die "VM $vmid returned an invalid redacted guest-agent response"
  exit_code="$(jq -r '.exitcode // -1' <<<"$result")"
  [[ "$exit_code" -eq 0 ]] || wslab_die "Guest phase failed on VM $vmid with redacted exit code $exit_code"
  jq -r '."out-data" // empty' <<<"$result" | tr -d '\r'
}

wait_for_first_boot_cleanup() {
  local vmid="$1" started elapsed readiness_script encoded result exit_code state
  read -r -d '' readiness_script <<'POWERSHELL' || true
$ErrorActionPreference = 'Stop'
$root = 'C:\ProgramData\WindowsServerLab'
$completePath = Join-Path $root 'first-boot-cleanup.complete'
$logPath = Join-Path $root 'Logs\first-boot-cleanup.log'
if (Test-Path -LiteralPath $completePath -PathType Leaf) {
    'complete'
}
elseif ((Test-Path -LiteralPath $logPath -PathType Leaf) -and (Select-String -LiteralPath $logPath -SimpleMatch 'FAILED:' -Quiet)) {
    'failed'
}
else {
    'pending'
}
POWERSHELL
  encoded="$(printf '%s' "$readiness_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
  started="$(awk '{print int($1)}' /proc/uptime)"
  while true; do
    result=""
    if result="$(qm guest exec "$vmid" --timeout 60 -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded" 2>/dev/null)"; then
      exit_code="$(jq -r '.exitcode // -1' <<<"$result")"
      state="$(jq -r '."out-data" // empty' <<<"$result" | tr -d '\r\n')"
      if [[ "$exit_code" -eq 0 && "$state" == "complete" ]]; then
        return 0
      fi
      [[ "$state" != "failed" ]] || wslab_die "Sealed first-boot hardening failed on VM $vmid"
    fi
    elapsed="$(( $(awk '{print int($1)}' /proc/uptime) - started ))"
    ((elapsed < timeout_seconds)) || wslab_die "Sealed first-boot hardening for VM $vmid did not complete within ${timeout_seconds}s"
    sleep 5
  done
}

sync_payload() {
  local vmid="$1" mapping="$2" source_path destination_path digest transfer_script payload
  source_path="$WSLAB_ROOT/${mapping%%|*}"
  destination_path="${mapping#*|}"
  [[ -r "$source_path" ]] || wslab_die "Required guest payload is missing: $source_path"
  digest="$(sha256sum "$source_path" | awk '{print $1}')"
  read -r -d '' transfer_script <<POWERSHELL || true
\$ErrorActionPreference = 'Stop'
\$destination = '$destination_path'
\$bytes = [Convert]::FromBase64String([Console]::In.ReadToEnd())
\$directory = Split-Path -Parent \$destination
if (-not (Test-Path -LiteralPath \$directory)) { New-Item -Path \$directory -ItemType Directory -Force | Out-Null }
[IO.File]::WriteAllBytes(\$destination, \$bytes)
\$actual = (Get-FileHash -LiteralPath \$destination -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if (\$actual -ne '$digest') { throw 'Transferred payload hash verification failed.' }
POWERSHELL
  payload="$(base64 -w 0 "$source_path")"
  qga_exec "$vmid" "$transfer_script" "$payload" >/dev/null
  payload=""
}

restart_guest() {
  local vmid="$1" started saw_down="false" elapsed restart_script encoded
  restart_script='Restart-Computer -Force'
  encoded="$(printf '%s' "$restart_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)"
  qm guest exec "$vmid" --timeout 60 -- powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded" >/dev/null 2>&1 || true
  started="$(awk '{print int($1)}' /proc/uptime)"
  while true; do
    if qm guest cmd "$vmid" ping >/dev/null 2>&1; then
      [[ "$saw_down" == "false" ]] || break
    else
      saw_down="true"
    fi
    elapsed="$(( $(awk '{print int($1)}' /proc/uptime) - started ))"
    ((elapsed < timeout_seconds)) || wslab_die "VM $vmid did not complete its required restart within ${timeout_seconds}s"
    sleep 5
  done
}

bootstrap_guest() {
  local vmid="$1" role="$2" bootstrap_script stdin_bundle output report_json restart_required pending_count attempt
  for attempt in 1 2 3 4 5; do
    read -r -d '' bootstrap_script <<POWERSHELL || true
\$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
\$values = @([Console]::In.ReadToEnd() -split "\r?\n")
if (\$values.Count -lt 3 -or @(\$values[0..2] | Where-Object { [string]::IsNullOrWhiteSpace(\$_) }).Count -gt 0) { throw 'Three runtime secrets are required.' }
\$adminSecure = \$null
\$dsrmSecure = \$null
\$userSecure = \$null
function ConvertTo-EphemeralSecureString {
    param([Parameter(Mandatory)][string]\$Value)
    \$secureValue = [Security.SecureString]::new()
    foreach (\$character in \$Value.ToCharArray()) { \$secureValue.AppendChar(\$character) }
    \$secureValue.MakeReadOnly()
    return \$secureValue
}
try {
    \$adminSecure = ConvertTo-EphemeralSecureString -Value \$values[0]
    \$dsrmSecure = ConvertTo-EphemeralSecureString -Value \$values[1]
    \$userSecure = ConvertTo-EphemeralSecureString -Value \$values[2]
    \$credential = [Management.Automation.PSCredential]::new('$netbios_name\Administrator', \$adminSecure)
    if ('$role' -eq 'primary-dc' -and -not (Get-Service NTDS -ErrorAction Ignore)) {
        \$administrator = Get-LocalUser | Where-Object { \$_.SID.Value -match '-500\$' } | Select-Object -First 1
        if (-not \$administrator) { throw 'Built-in Administrator account was not found.' }
        Set-LocalUser -SID \$administrator.SID -Password \$adminSecure -PasswordNeverExpires \$false -ErrorAction Stop
        Enable-LocalUser -SID \$administrator.SID -ErrorAction Stop
    }
    & 'C:\ProgramData\WindowsServerLab\Scripts\Invoke-LabBootstrap.ps1' -VmId $vmid -Role '$role' -DomainName '$domain_name' -DsrmPassword \$dsrmSecure -DefaultUserPassword \$userSecure -DomainCredential \$credential -CreatePrivilegedAccounts -Confirm:\$false | Out-Null
    Get-Content -LiteralPath 'C:\ProgramData\WindowsServerLab\Reports\bootstrap-$vmid.json' -Raw -Encoding UTF8 |
        ConvertFrom-Json -ErrorAction Stop |
        ConvertTo-Json -Depth 8 -Compress
}
finally {
    \$values = @()
    if (\$adminSecure) { \$adminSecure.Dispose() }
    if (\$dsrmSecure) { \$dsrmSecure.Dispose() }
    if (\$userSecure) { \$userSecure.Dispose() }
}
POWERSHELL
    stdin_bundle="$(printf '%s\n%s\n%s' "$domain_admin_password" "$dsrm_password" "$lab_user_password")"
    output="$(qga_exec "$vmid" "$bootstrap_script" "$stdin_bundle")"
    stdin_bundle=""
    report_json="$(tail -n 1 <<<"$output" | tr -d '\r')"
    jq -e 'type == "object" and .status != "failed"' >/dev/null <<<"$report_json" || wslab_die "VM $vmid returned invalid redacted bootstrap evidence"
    restart_required="$(jq '[.pending[]? | select(startswith("restart-"))] | length > 0' <<<"$report_json")"
    pending_count="$(jq '.pending | length' <<<"$report_json")"
    if [[ "$restart_required" == "true" ]]; then
      wslab_log INFO "VM $vmid completed bootstrap stage $attempt and requires a health-checked restart"
      restart_guest "$vmid"
      continue
    fi
    ((pending_count == 0)) || wslab_die "VM $vmid remains pending: $(jq -r '.pending | join(", ")' <<<"$report_json")"
    return 0
  done
  wslab_die "VM $vmid did not converge after five bootstrap stages"
}

while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  wslab_qm_exists "$vmid" || wslab_die "VM $vmid ($name) has not been deployed"
  wslab_qm_has_tag "$vmid" wslab || wslab_die "VM $vmid is not owned by WindowsServerLab"
  [[ "$(qm status "$vmid" | awk '{print $2}')" == "running" ]] || wslab_die "VM $vmid ($name) is not running"
  wslab_wait_for_guest_agent "$vmid" "$timeout_seconds"
  wslab_log INFO "Waiting for sealed first-boot hardening on $name"
  wait_for_first_boot_cleanup "$vmid"
  wslab_log INFO "Synchronizing current configuration payload to $name"
  for mapping in "${payloads[@]}"; do sync_payload "$vmid" "$mapping"; done
done < <(wslab_virtual_machines "$definition_file")

while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  role="$(jq -r '.role' <<<"$vm")"
  name="$(jq -r '.name' <<<"$vm")"
  wslab_log INFO "Reconciling $name as $role"
  bootstrap_guest "$vmid" "$role"
done < <(wslab_virtual_machines "$definition_file")

while IFS= read -r vm; do
  vmid="$(jq -r '.id' <<<"$vm")"
  role="$(jq -r '.role' <<<"$vm")"
  if [[ "$role" == "client" ]]; then
    baseline_script="& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabClientSecurityBaseline.ps1' -Confirm:\$false | Out-Null"
  else
    baseline_role="MemberServer"
    [[ "$role" == "primary-dc" || "$role" == "secondary-dc" ]] && baseline_role="DomainController"
    baseline_script="& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabSecurityBaseline.ps1' -ServerRole '$baseline_role' -EnableAppControlAudit -Confirm:\$false | Out-Null"
  fi
  wslab_log INFO "Applying the verified security baseline to VM $vmid"
  qga_exec "$vmid" "$baseline_script" >/dev/null
done < <(wslab_virtual_machines "$definition_file")

primary_id="$(wslab_virtual_machines "$definition_file" | jq -r 'select(.role == "primary-dc") | .id')"
file_id="$(wslab_virtual_machines "$definition_file" | jq -r 'select(.role == "file-server") | .id')"
management_id="$(wslab_virtual_machines "$definition_file" | jq -r 'select(.role == "management-server") | .id')"

wslab_log INFO "Reconciling final DHCP DNS options after both domain controllers are ready"
dhcp_script="Import-Module 'C:\ProgramData\WindowsServerLab\Modules\WindowsServerLab\WindowsServerLab.psd1' -Force -ErrorAction Stop; \$definition = Import-LabDefinition -Path 'C:\ProgramData\WindowsServerLab\LabConfig\lab.json'; Set-LabDhcpService -Definition \$definition -RequireAllDnsServers -Confirm:\$false"
qga_exec "$primary_id" "$dhcp_script" >/dev/null

branding_script="& 'C:\ProgramData\WindowsServerLab\Scripts\New-LabAsgardBranding.ps1' -Confirm:\$false | Out-Null"
qga_exec "$file_id" "$branding_script" >/dev/null

client_policy_commands=""
while IFS= read -r client; do
  client_name="$(jq -r '.name' <<<"$client")"
  lab_user="$(jq -r '.user.samAccountName' <<<"$client")"
  client_policy_commands+="& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1' -Identity '$lab_user' -Control Wallpaper -Access Deny -RefreshPolicy -Confirm:\$false | Out-Null"$'\n'
  client_policy_commands+="& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1' -Identity '$client_name' -Control Camera -Access Deny -RefreshPolicy -Confirm:\$false | Out-Null"$'\n'
  client_policy_commands+="& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabAccessControl.ps1' -Identity '$client_name' -Control USBStorage -Access Deny -RefreshPolicy -Confirm:\$false | Out-Null"$'\n'
done < <(wslab_virtual_machines "$definition_file" | jq -c 'select(.role == "client")')

read -r -d '' policy_script <<POWERSHELL || true
\$ErrorActionPreference = 'Stop'
\$wallpaper = '\\HEIMDALL-FS01.$domain_name\Branding\asgard-wallpaper.bmp'
& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabDomainPolicy.ps1' -ConfigureLaps -ConfigureAccessControls -ConfigurePrintPolicy -WallpaperPath \$wallpaper -Confirm:\$false | Out-Null
& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabFileSharePolicy.ps1' -ShareName AsgardData -Initialize -DefaultReadForDomainUsers -Confirm:\$false | Out-Null
$client_policy_commands
POWERSHELL
qga_exec "$primary_id" "$policy_script" >/dev/null
client_policy_check="if ((Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Camera' -Name AllowCamera -ErrorAction Ignore) -eq 0 -and (Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices' -Name Deny_All -ErrorAction Ignore) -eq 1) { 'effective' } else { 'pending' }"
while IFS= read -r client_id; do
  if [[ "$(qga_exec "$client_id" "$client_policy_check" | tail -n 1)" != "effective" ]]; then
    restart_guest "$client_id"
    [[ "$(qga_exec "$client_id" "$client_policy_check" | tail -n 1)" == "effective" ]] || wslab_die "Camera and USB-storage policy did not become effective on VM $client_id"
  fi
done < <(wslab_virtual_machines "$definition_file" | jq -r 'select(.role == "client") | .id')

read -r -d '' file_script <<'POWERSHELL' || true
$ErrorActionPreference = 'Stop'
Import-Module ServerManager -ErrorAction Stop
if (-not (Get-WindowsFeature Print-Server -ErrorAction Stop).Installed) { Install-WindowsFeature Print-Server -IncludeManagementTools -ErrorAction Stop | Out-Null }
& 'C:\ProgramData\WindowsServerLab\Scripts\Set-LabSharedFolder.ps1' -ShareName AsgardData -Path 'D:\Shares\AsgardData' -Confirm:$false | Out-Null
POWERSHELL
qga_exec "$file_id" "$file_script" >/dev/null

wef_script="& 'C:\ProgramData\WindowsServerLab\Scripts\Enable-LabEventForwarding.ps1' -Confirm:\$false"
qga_exec "$management_id" "$wef_script" >/dev/null

report_directory="$(wslab_report_directory "$site_file")"
mkdir -p "$report_directory"
report_file="$report_directory/configure-$(date -u +%Y%m%dT%H%M%SZ).json"
jq -n --arg domain "$domain_name" \
  '{schemaVersion:3,timestamp:(now|todate),status:"configured",lab:"asgard",domain:$domain,secretsRetained:false,printerQueue:"deferred-pending-hardware-and-signed-driver"}' >"$report_file"
chmod 0640 "$report_file"
wslab_log PASS "Configured the Asgard lab Active Directory, services, access controls, print/file policy, and background GPO refresh"
wslab_log INFO "Redacted configuration evidence: $report_file"
