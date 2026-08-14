#!/usr/bin/env bash

set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SITE="$REPO_ROOT/LabConfig/site.example.json"
LAB="$REPO_ROOT/LabConfig/lab.json"
VALIDATE="$REPO_ROOT/Tools/Proxmox/Validate-LabConfig.sh"
TEST_LAB="$REPO_ROOT/Tools/Proxmox/Test-Lab.sh"
RENDER_ANSWER="$REPO_ROOT/Tools/Proxmox/Render-WindowsAnswerMedia.py"
CERTIFY="$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh"
ACTIVATE="$REPO_ROOT/Tools/Proxmox/Activate-LabGuests.sh"
TEMP_DIR="$(mktemp -d)"
cleanup() {
  case "$TEMP_DIR" in
    /tmp/*|/var/folders/*) rm -rf -- "$TEMP_DIR" ;;
    *) printf 'Refusing to remove unexpected temporary path: %s\n' "$TEMP_DIR" >&2 ;;
  esac
}
trap cleanup EXIT

for required_command in jq python3 rg; do
  command -v "$required_command" >/dev/null 2>&1 || {
    printf 'Required test command is missing: %s\n' "$required_command" >&2
    exit 1
  }
done

file_mode() {
  if [[ "$(uname -s)" == "Darwin" ]]; then stat -f '%Lp' "$1"; else stat -c '%a' "$1"; fi
}

"$VALIDATE" --site "$SITE" >"$TEMP_DIR/validate.log"
grep -q '6 VMs (5 servers, 1 client), 11 vCPU, 17408 MB RAM, 456 GB' "$TEMP_DIR/validate.log"
"$TEST_LAB" --site "$SITE" --phase full --offline >"$TEMP_DIR/offline-test.json"
grep -q '"passed": true' "$TEMP_DIR/offline-test.json"

jq '.hostNetworking.sharedManagementBridge = false' "$SITE" >"$TEMP_DIR/invalid-shared-mapping.json"
jq '.hostNetworking.allowedVlans = [90, 101]' "$SITE" >"$TEMP_DIR/invalid-vlans.json"
jq '.proxmox.templates["windows-11"] = 9000' "$SITE" >"$TEMP_DIR/duplicate-template.json"
jq '.templateCertification.vmId = 9000' "$SITE" >"$TEMP_DIR/certification-conflict.json"
jq '.password = "must-not-be-accepted"' "$SITE" >"$TEMP_DIR/site-with-secret.json"
for invalid in invalid-shared-mapping invalid-vlans duplicate-template certification-conflict site-with-secret; do
  if "$VALIDATE" --site "$TEMP_DIR/$invalid.json" >/dev/null 2>&1; then
    printf 'Invalid fixture was accepted: %s\n' "$invalid" >&2
    exit 1
  fi
done

jq -e '
  (.virtualMachines | length == 6) and
  ([.virtualMachines[].id] | unique | length == 6) and
  ([.virtualMachines[].name] | unique | length == 6) and
  ([.virtualMachines[].nics[].ipAddress] | unique | length == 6) and
  ([.virtualMachines[] | select(.os == "server-2025")] | length == 5) and
  ([.virtualMachines[] | select(.os == "windows-11")] | length == 1) and
  ([.virtualMachines[].cores] | add == 11) and
  ([.virtualMachines[].memoryMB] | add == 17408) and
  ([.virtualMachines[] | .diskGB + ((.dataDisks // []) | map(.sizeGB) | add // 0)] | add == 456)
' "$LAB" >/dev/null

for removed in \
  Tools/Proxmox/Deploy-Lab.sh \
  Tools/Proxmox/Remove-Lab.sh \
  Tools/Proxmox/Configure-LabNetwork.sh \
  LabConfig/demos/asgard.json \
  LabConfig/demos/olympus.json; do
  [[ ! -e "$REPO_ROOT/$removed" ]] || { printf 'Removed path still exists: %s\n' "$removed" >&2; exit 1; }
done

if rg -n -i --glob '*.sh' --glob '*.ps1' --glob '*.psm1' --glob '*.psd1' \
  -- '--demo|--profile|LabConfig[\\/]demos|aiml-client|server-2022|olympus' \
  "$REPO_ROOT/Tools/Proxmox" "$REPO_ROOT/Tools/Terraform" "$REPO_ROOT/Scripts/WindowsServerLab" \
  "$REPO_ROOT/Scripts/Initialize-LabDomain.ps1" "$REPO_ROOT/Scripts/Initialize-LabDataDisks.ps1" \
  "$REPO_ROOT/Scripts/Invoke-LabBootstrap.ps1" "$REPO_ROOT/Scripts/Invoke-LabWindowsActivation.ps1"; then
  echo 'A supported operational path still exposes the removed profile or OS API.' >&2
  exit 1
fi

"$CERTIFY" --os server-2025 --site "$SITE" >"$TEMP_DIR/certify.plan"
grep -q 'two sequential clones using VM ID 9090' "$TEMP_DIR/certify.plan"
"$ACTIVATE" --site "$SITE" --action activate >"$TEMP_DIR/activate.plan"
grep -q 'send them only over guest-agent stdin' "$TEMP_DIR/activate.plan"
if grep -Eq '[A-Z0-9]{5}(-[A-Z0-9]{5}){4}' "$TEMP_DIR/activate.plan"; then
  echo 'Activation material appeared in a dry-run plan.' >&2
  exit 1
fi

for os_name in server-2025 windows-11; do
  answer_directory="$TEMP_DIR/answer-media-$os_name"
  mkdir "$answer_directory"
  PKR_VAR_windows_password='Runtime<&BuildValue' \
  PKR_VAR_cloudbase_msi_sha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
  PKR_VAR_osconfig_nupkg_sha256='cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc' \
  PKR_VAR_osconfig_version='1.4.3' \
  WSLAB_QEMU_AGENT_MSI_SHA256='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' \
  WSLAB_BUILD_IPV4_ADDRESS='192.0.2.249' \
  WSLAB_BUILD_IPV4_PREFIX_LENGTH='24' \
  WSLAB_BUILD_IPV4_GATEWAY='192.0.2.1' \
  WSLAB_BUILD_DNS_SERVERS='192.0.2.1,192.0.2.2' \
  python3 "$RENDER_ANSWER" --os "$os_name" --template-directory "$REPO_ROOT/packer/windows" --output-directory "$answer_directory"
  python3 -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$answer_directory/Autounattend.xml"
  grep -q 'Runtime&lt;&amp;BuildValue' "$answer_directory/Autounattend.xml"
  grep -Fq '<WillShowUI>Never</WillShowUI>' "$answer_directory/Autounattend.xml"
  grep -Fq "manifest.os -ne '$os_name'" "$answer_directory/bootstrap.ps1"
  [[ "$(file_mode "$answer_directory/Autounattend.xml")" == "600" ]]
done
grep -Fq '<Key>TVRH6-WHNXV-R9WG3-9XRFY-MY832</Key>' "$TEMP_DIR/answer-media-server-2025/Autounattend.xml"
grep -Fq 'E:\vioscsi\2k25\amd64' "$TEMP_DIR/answer-media-server-2025/Autounattend.xml"
grep -Fq '<Value>2</Value>' "$TEMP_DIR/answer-media-server-2025/Autounattend.xml"
grep -Fq '<Key>NW6C2-QMPVW-D7KKK-3GKT6-VCFB2</Key>' "$TEMP_DIR/answer-media-windows-11/Autounattend.xml"
grep -Fq 'E:\vioscsi\w11\amd64' "$TEMP_DIR/answer-media-windows-11/Autounattend.xml"
grep -Fq '<Value>Windows 11 Education</Value>' "$TEMP_DIR/answer-media-windows-11/Autounattend.xml"
grep -Fq 'Get-Command -Name Get-BitLockerVolume' "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq -- '-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries' "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq "manifest.os -eq 'server-2025'" "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq "Get-Content -LiteralPath \$manifestPath -Raw -Encoding UTF8" "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq "CreateElement('ProductKey'" "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq "WSLAB_WINDOWS_SETUP_KEY=\${var.windows_setup_key}" "$REPO_ROOT/packer/windows/windows.pkr.hcl"
grep -Fq "PKR_VAR_windows_setup_key='TVRH6-WHNXV-R9WG3-9XRFY-MY832'" "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq "PKR_VAR_windows_setup_key='NW6C2-QMPVW-D7KKK-3GKT6-VCFB2'" "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq 'PKR_VAR_windows_password PKR_VAR_windows_setup_key PKR_VAR_cloudbase_msi_url' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq 'PKR_VAR_osconfig_version PKR_VAR_osconfig_nupkg_url PKR_VAR_osconfig_nupkg_sha256' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq 'microsoftOsConfigReady' "$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh"
grep -Fq 'seal.failed' "$REPO_ROOT/packer/windows/wait-for-template-shutdown.sh"
grep -Fq "first-boot-cleanup.complete" "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"
grep -Fq "wait_for_first_boot_cleanup \"\$vmid\"" "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"
grep -Fq 'ConvertTo-Json -Depth 8 -Compress' "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"
grep -Fq 'ServerAliveInterval=15' "$REPO_ROOT/Tools/Terraform/Remote-Run.sh"
grep -Fq 'ServerAliveCountMax=3' "$REPO_ROOT/Tools/Terraform/Remote-Run.sh"
grep -Fq 'Read-only remote inspection attempt %d failed; retrying.' "$REPO_ROOT/Tools/Terraform/Remote-External.sh"
grep -Fq 'systemd-run --collect' "$REPO_ROOT/Tools/Terraform/Remote-Run.sh"
grep -Fq "tar -xzf \"\$runtime/repository.tar.gz\" -C \"\$runtime\"" "$REPO_ROOT/Tools/Terraform/Remote-Run.sh"
grep -Fq 'flock 9' "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"
grep -Fq "PSObject.Properties[\$Name]" "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq "Get-RegistryBooleanValue -RegistryItem \$currentPolicy -Name 'auth_certificate'" "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq "\$domain.DomainControllersContainer" "$REPO_ROOT/Scripts/WindowsServerLab/WindowsServerLab.psm1"
grep -Fq "\$vm.role -in @('primary-dc', 'secondary-dc')" "$REPO_ROOT/Scripts/WindowsServerLab/WindowsServerLab.psm1"
grep -Fq "\$isDomainController = \$computerSystem.DomainRole -in @(4, 5)" "$REPO_ROOT/Scripts/Invoke-LabBootstrap.ps1"
grep -Fq "if (\$isDomainController -and \$ntdsService.Status -eq 'Running'" "$REPO_ROOT/Scripts/Invoke-LabBootstrap.ps1"
grep -Fq "promotion-\$VmId.pending" "$REPO_ROOT/Scripts/Invoke-LabBootstrap.ps1"
grep -Fq 'Get-DhcpServerInDC -ErrorAction Stop' "$REPO_ROOT/Scripts/Invoke-LabBootstrap.ps1"
grep -Fq 'WINRM-HTTP-In-TCP-PUBLIC' "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq "Disable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP-PUBLIC'" "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq "Where-Object { \$_.LocalPort -eq '5986' }" "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq 'auth_negotiate' "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq 'Restart-Service -Name WinRM -Force' "$REPO_ROOT/Scripts/Enable-LabPowerShellRemoting.ps1"
grep -Fq "Where-Object network -eq 'windowsServers'" "$REPO_ROOT/Scripts/WindowsServerLab/WindowsServerLab.psm1"
grep -Fq 'Set-LabDhcpService -Definition' "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"
grep -Fq -- '-RequireAllDnsServers' "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"
grep -Fq "Test-NetConnection -ComputerName \$_ -Port 53" "$REPO_ROOT/Scripts/WindowsServerLab/WindowsServerLab.psm1"

grep -Fq 'source  = "bpg/proxmox"' "$REPO_ROOT/terraform/lab/versions.tf"
grep -Fq 'version = "= 0.111.1"' "$REPO_ROOT/terraform/lab/versions.tf"
grep -Fq 'module "foundation"' "$REPO_ROOT/terraform/main.tf"
grep -Fq 'module "lab"' "$REPO_ROOT/terraform/main.tf"
grep -Fq 'WSLAB_REMOTE_OPERATION             = "configure-guests"' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'proxmox_host                 = "192.168.10.50"' "$REPO_ROOT/terraform/terraform.tfvars.example"
grep -Fq 'proxmox_node                 = "pve2"' "$REPO_ROOT/terraform/terraform.tfvars.example"
grep -Fq 'proxmox_ssh_private_key_path = "~/.ssh/id_ed25519"' "$REPO_ROOT/terraform/terraform.tfvars.example"
grep -Fq '"member-server"' "$REPO_ROOT/LabConfig/schema/lab.schema.json"
if grep -Eq 'source\s*=.*(LabConfig/lab\.json|/Scripts)' "$REPO_ROOT/packer/windows/windows.pkr.hcl"; then
  echo 'Mutable inventory or guest-role scripts were embedded in a Packer template.' >&2
  exit 1
fi
grep -Fq 'full         = true' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'pre_enrolled_keys = true' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'version      = "v2.0"' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'firewall = true' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'stop_on_destroy                      = false' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'purge_on_destroy                     = true' "$REPO_ROOT/terraform/lab/main.tf"
grep -Fq 'depends_on = [terraform_data.foundation_guard]' "$REPO_ROOT/terraform/foundation/main.tf"
grep -Fq 'vids       = join' "$REPO_ROOT/terraform/foundation/main.tf"
grep -Fq 'count = local.shared_management_bridge ? 0 : 1' "$REPO_ROOT/terraform/foundation/main.tf"
grep -Fq '**/.terraform/*' "$REPO_ROOT/.gitignore"
grep -Fq '*.tfstate' "$REPO_ROOT/.gitignore"

if grep -R -E -n 'ConvertTo-SecureString.+AsPlainText' \
  "$REPO_ROOT/packer/windows" \
  "$REPO_ROOT/Tools/Proxmox/Activate-LabGuests.sh" \
  "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh" >/dev/null; then
  echo 'Runtime template, activation, or guest-configuration secrets are converted from plaintext.' >&2
  exit 1
fi

echo 'Shell/configuration tests passed.'
