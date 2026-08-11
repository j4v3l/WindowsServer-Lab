#!/usr/bin/env bash

set -euo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SITE="$REPO_ROOT/LabConfig/site.example.json"
VALIDATE="$REPO_ROOT/Tools/Proxmox/Validate-LabConfig.sh"
DEPLOY="$REPO_ROOT/Tools/Proxmox/Deploy-Lab.sh"
REMOVE="$REPO_ROOT/Tools/Proxmox/Remove-Lab.sh"
TEST_LAB="$REPO_ROOT/Tools/Proxmox/Test-Lab.sh"
RENDER_ANSWER="$REPO_ROOT/Tools/Proxmox/Render-WindowsAnswerMedia.py"
CERTIFY="$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh"
ACTIVATE="$REPO_ROOT/Tools/Proxmox/Activate-LabGuests.sh"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi
}

file_mode() {
  if [[ "$(uname -s)" == "Darwin" ]]; then stat -f '%Lp' "$1"; else stat -c '%a' "$1"; fi
}

for demo in asgard olympus; do
  for profile in smoke core full; do
    if [[ "$demo" == "asgard" && "$profile" != "smoke" ]]; then
      if "$VALIDATE" --demo "$demo" --profile "$profile" --site "$SITE" >/dev/null 2>&1; then
        echo "Asgard $profile was accepted without explicit management/DMZ site mappings." >&2
        exit 1
      fi
      continue
    fi
    "$VALIDATE" --demo "$demo" --profile "$profile" --site "$SITE" >/dev/null
    "$DEPLOY" --demo "$demo" --profile "$profile" --site "$SITE" >"$TEMP_DIR/$demo-$profile.plan"
    case "$profile" in
      smoke) expected=6 ;;
      core) expected=7 ;;
      full) expected=30 ;;
    esac
    actual="$(grep -c 'qm clone' "$TEMP_DIR/$demo-$profile.plan")"
    [[ "$actual" -eq "$expected" ]] || { echo "$demo/$profile expected $expected clone commands, found $actual" >&2; exit 1; }
    grep '^  qm clone' "$TEMP_DIR/$demo-$profile.plan" | sed 's/[[:space:]]*$//' >"$TEMP_DIR/$demo-$profile.clones"
    actual_hash="$(sha256_file "$TEMP_DIR/$demo-$profile.clones")"
    expected_hash="$(awk -v key="$demo-$profile" '$2 == key { print $1 }' "$REPO_ROOT/Tests/Snapshots/deploy-clone.sha256")"
    [[ "$actual_hash" == "$expected_hash" ]] || { echo "$demo/$profile command snapshot changed: $actual_hash" >&2; exit 1; }
    "$REMOVE" --demo "$demo" --profile "$profile" --site "$SITE" >"$TEMP_DIR/$demo-$profile.remove"
    actual="$(grep -c 'qm destroy' "$TEMP_DIR/$demo-$profile.remove")"
    [[ "$actual" -eq "$expected" ]] || { echo "$demo/$profile expected $expected destroy commands, found $actual" >&2; exit 1; }
    "$TEST_LAB" --demo "$demo" --profile "$profile" --site "$SITE" --phase full --offline >"$TEMP_DIR/$demo-$profile.test"
    grep -q '"passed": true' "$TEMP_DIR/$demo-$profile.test"
  done
done

jq '.guestAccess.sshPublicKeyFile = "/tmp/key with space.pub"' "$SITE" >"$TEMP_DIR/site with spaces.json"
"$DEPLOY" --demo asgard --profile smoke --site "$TEMP_DIR/site with spaces.json" >"$TEMP_DIR/escaped.plan"
grep -q -- '--sshkeys /tmp/key\\ with\\ space.pub' "$TEMP_DIR/escaped.plan"

jq '.capacity.memoryMB = 4096' "$SITE" >"$TEMP_DIR/undersized-site.json"
if "$VALIDATE" --demo asgard --profile smoke --site "$TEMP_DIR/undersized-site.json" >/dev/null 2>&1; then
  echo 'An undersized site was accepted.' >&2
  exit 1
fi

jq '.password = "must-not-be-accepted"' "$SITE" >"$TEMP_DIR/site-with-secret.json"
if "$VALIDATE" --demo asgard --profile core --site "$TEMP_DIR/site-with-secret.json" >/dev/null 2>&1; then
  echo 'Configuration containing a password field was accepted.' >&2
  exit 1
fi

grep -q 'ad.asgard.test' "$TEMP_DIR/asgard-smoke.plan"
grep -q 'ad.olympus.test' "$TEMP_DIR/olympus-core.plan"
grep -q -- '--cores 2 --memory 3072 --balloon 2560' "$TEMP_DIR/asgard-smoke.plan"
grep -q -- '--cores 1 --memory 2048 --balloon 2048' "$TEMP_DIR/asgard-smoke.plan"
[[ "$(grep -c 'qm disk resize' "$TEMP_DIR/asgard-smoke.plan")" -eq 0 ]]
grep -q 'qm set 5102 --scsi1 local-lvm:56' "$TEMP_DIR/asgard-smoke.plan"
grep -q 'bridge=vmbr1.*tag=90' "$TEMP_DIR/asgard-smoke.plan"
grep -q 'bridge=vmbr1.*tag=100' "$TEMP_DIR/asgard-smoke.plan"
grep -q 'ip=192.168.90.10/24.*gw=192.168.90.1' "$TEMP_DIR/asgard-smoke.plan"
grep -q 'ip=192.168.100.10/24.*gw=192.168.100.1' "$TEMP_DIR/asgard-smoke.plan"
grep -q 'qm set 5100 --ide2 local-lvm:cloudinit' "$TEMP_DIR/asgard-smoke.plan"

"$CERTIFY" --os server-2025 --site "$SITE" >"$TEMP_DIR/certify-server-2025.plan"
grep -q 'two sequential clones using VM ID 9090' "$TEMP_DIR/certify-server-2025.plan"
grep -q '192.0.2.248/24' "$TEMP_DIR/certify-server-2025.plan"
"$ACTIVATE" --demo asgard --profile smoke --site "$SITE" --action activate >"$TEMP_DIR/activate.plan"
grep -q 'send them only over guest-agent stdin' "$TEMP_DIR/activate.plan"
if grep -Eq '[A-Z0-9]{5}(-[A-Z0-9]{5}){4}' "$TEMP_DIR/activate.plan"; then
  echo 'Activation material appeared in a dry-run plan.' >&2
  exit 1
fi

jq '.templateCertification.vmId = 9000' "$SITE" >"$TEMP_DIR/certification-id-conflict.json"
if "$VALIDATE" --demo asgard --profile smoke --site "$TEMP_DIR/certification-id-conflict.json" >/dev/null 2>&1; then
  echo 'A certification VM ID colliding with a template was accepted.' >&2
  exit 1
fi

mkdir "$TEMP_DIR/answer-media"
PKR_VAR_windows_password='Runtime<&BuildValue' \
PKR_VAR_cloudbase_msi_sha256='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
WSLAB_QEMU_AGENT_MSI_SHA256='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' \
WSLAB_BUILD_IPV4_ADDRESS='192.0.2.249' \
WSLAB_BUILD_IPV4_PREFIX_LENGTH='24' \
WSLAB_BUILD_IPV4_GATEWAY='192.0.2.1' \
WSLAB_BUILD_DNS_SERVERS='192.0.2.1,192.0.2.2' \
python3 "$RENDER_ANSWER" --os server-2025 --template-directory "$REPO_ROOT/packer/windows" --output-directory "$TEMP_DIR/answer-media"
python3 -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$TEMP_DIR/answer-media/Autounattend.xml"
grep -Fq 'name="Microsoft-Windows-International-Core"' "$TEMP_DIR/answer-media/Autounattend.xml"
grep -q 'Runtime&lt;&amp;BuildValue' "$TEMP_DIR/answer-media/Autounattend.xml"
[[ "$(grep -o 'Runtime&lt;&amp;BuildValue' "$TEMP_DIR/answer-media/Autounattend.xml" | wc -l | tr -d ' ')" -eq 3 ]]
grep -Fq 'E:\vioscsi\2k25\amd64' "$TEMP_DIR/answer-media/Autounattend.xml"
[[ "$(grep -c 'PathAndCredentials' "$TEMP_DIR/answer-media/Autounattend.xml")" -eq 3 ]]
if grep -Fqi 'drvload.exe' "$TEMP_DIR/answer-media/Autounattend.xml"; then
  echo 'VirtIO drivers must have exactly one unattended injection path.' >&2
  exit 1
fi
[[ "$(grep -o 'vioscsi\\2k25\\amd64' "$TEMP_DIR/answer-media/Autounattend.xml" | wc -l | tr -d ' ')" -eq 1 ]]
if grep -Fq -- "-type f \\( -name 'wslab-answer-*.iso'" "$REPO_ROOT/Tools/Proxmox/Inspect-RemoteHost.sh"; then
  echo 'Remote stale-media inspection must not pass unquoted shell parentheses through SSH.' >&2
  exit 1
fi
stale_media_fixture_count="$(printf '%s\n' '/iso/windows.iso' '/iso/wslab-install-test.iso' '/iso/wslab-answer-test.iso' | awk '/wslab-(answer|install)-.*[.]iso$/ { count++ } END { print count + 0 }')"
[[ "$stale_media_fixture_count" -eq 2 ]] || { echo 'Portable stale-media matching failed.' >&2; exit 1; }
grep -q "Runtime<&BuildValue" "$TEMP_DIR/answer-media/bootstrap.ps1"
grep -q '192.0.2.249' "$TEMP_DIR/answer-media/bootstrap.ps1"
grep -q "'192.0.2.1', '192.0.2.2'" "$TEMP_DIR/answer-media/bootstrap.ps1"
grep -q 'Get-Volume -FileSystemLabel WSLABDATA' "$TEMP_DIR/answer-media/bootstrap.ps1"
grep -q 'payload-manifest.json' "$TEMP_DIR/answer-media/bootstrap.ps1"
grep -Fq "manifest.os -ne 'server-2025'" "$TEMP_DIR/answer-media/bootstrap.ps1"
# Rendered PowerShell expressions are intentionally matched literally.
# shellcheck disable=SC2016
if grep -Fq '${os_type}' "$TEMP_DIR/answer-media/bootstrap.ps1"; then
  echo 'The rendered bootstrap retained an operating-system template token.' >&2
  exit 1
fi
grep -q 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' "$TEMP_DIR/answer-media/bootstrap.ps1"
if grep -Fq 'E:\guest-agent' "$TEMP_DIR/answer-media/bootstrap.ps1"; then
  echo 'The rendered bootstrap still depends on the VirtIO CD drive letter.' >&2
  exit 1
fi
if grep -Fq 'Set-LocalUser -Name LabBootstrap -Password' "$TEMP_DIR/answer-media/bootstrap.ps1"; then
  echo 'Bootstrap must not mutate account flags on the only enabled administrator.' >&2
  exit 1
fi
if grep -Fq 'ConvertTo-SecureString' "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh"; then
  echo 'Guest configuration must not convert plaintext runtime secrets with ConvertTo-SecureString.' >&2
  exit 1
fi
if grep -R -E -n 'ConvertTo-SecureString.+AsPlainText' \
  "$REPO_ROOT/packer/windows" \
  "$REPO_ROOT/Tools/Proxmox/Activate-LabGuests.sh" \
  "$REPO_ROOT/Tools/Proxmox/Configure-LabGuests.sh" >/dev/null; then
  echo 'Runtime template, activation, or guest-configuration secrets are converted from plaintext.' >&2
  exit 1
fi
winrm_line="$(grep -n 'Temporary HTTPS WinRM diagnostic channel is ready' "$TEMP_DIR/answer-media/bootstrap.ps1" | cut -d: -f1)"
agent_line="$(grep -n "Install-VerifiedMsi -Name 'QEMU Guest Agent'" "$TEMP_DIR/answer-media/bootstrap.ps1" | cut -d: -f1)"
[[ "$winrm_line" -lt "$agent_line" ]] || { echo 'WinRM diagnostics must be ready before agent installation.' >&2; exit 1; }
# shellcheck disable=SC2016
grep -Fq 'CertificateThumbPrint $buildCertificate.Thumbprint -Force -Confirm:$false' "$TEMP_DIR/answer-media/bootstrap.ps1"
# shellcheck disable=SC2016
grep -Fq 'New-ItemProperty -LiteralPath $winRmServiceRegistry -Name auth_basic -PropertyType DWord -Value 1 -Force' "$TEMP_DIR/answer-media/bootstrap.ps1"
if grep -Fq 'Enable-PSRemoting' "$TEMP_DIR/answer-media/bootstrap.ps1"; then
  echo 'Template bootstrap reintroduced NLA-dependent HTTP remoting setup.' >&2
  exit 1
fi
[[ "$(file_mode "$TEMP_DIR/answer-media/Autounattend.xml")" == "600" ]]

printf 'cloudbase-fixture' >"$TEMP_DIR/answer-media/CloudbaseInitSetup.msi"
printf 'qemu-fixture' >"$TEMP_DIR/answer-media/qemu-ga-x86_64.msi"
jq -n '{schemaVersion:1,os:"server-2025",buildRunId:"test-run",sources:{windowsIsoSha256:("c"*64),virtioIsoSha256:("d"*64)},payloads:{cloudbaseInit:{file:"CloudbaseInitSetup.msi",sha256:("a"*64)},qemuGuestAgent:{file:"qemu-ga-x86_64.msi",sha256:("b"*64)}}}' >"$TEMP_DIR/answer-media/payload-manifest.json"
xorriso -as mkisofs -quiet -J -joliet-long -r -V WSLABDATA -o "$TEMP_DIR/answer.iso" \
  "$TEMP_DIR/answer-media/Autounattend.xml" \
  "$TEMP_DIR/answer-media/bootstrap.ps1" \
  "$TEMP_DIR/answer-media/payload-manifest.json" \
  "$TEMP_DIR/answer-media/CloudbaseInitSetup.msi" \
  "$TEMP_DIR/answer-media/qemu-ga-x86_64.msi"
xorriso -indev "$TEMP_DIR/answer.iso" -ls / 2>/dev/null >"$TEMP_DIR/answer-contents.txt"
for payload in Autounattend.xml bootstrap.ps1 payload-manifest.json CloudbaseInitSetup.msi qemu-ga-x86_64.msi; do
  grep -Fq "$payload" "$TEMP_DIR/answer-contents.txt" || { echo "Answer ISO is missing $payload" >&2; exit 1; }
done
grep -Fq '/generalize /oobe /shutdown' "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq 'WindowsServerLab-TemplateSeal' "$REPO_ROOT/packer/windows/finalize-template.ps1"
grep -Fq 'WindowsServerLab-FirstBootCleanup' "$REPO_ROOT/packer/windows/seal-template.ps1"
grep -Fq 'Plugins execution done' "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
grep -Fq 'first-boot-cleanup.complete' "$REPO_ROOT/packer/windows/first-boot-cleanup.ps1"
grep -Fq 'firstBootCleanupCompleted' "$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh"
grep -Fq 'wait-for-template-shutdown.sh' "$REPO_ROOT/packer/windows/windows.pkr.hcl"
[[ "$(grep -c 'additional_iso_files' "$REPO_ROOT/packer/windows/windows.pkr.hcl")" -eq 1 ]]
if grep -Fq 'answer_iso' "$REPO_ROOT/packer/windows/windows.pkr.hcl"; then
  echo 'The Packer template still declares a separate answer ISO.' >&2
  exit 1
fi
grep -Fq -- '-b boot/etfsboot.com' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq -- '-e efi/microsoft/boot/efisys.bin' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq -- '-allow-limited-size' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq 'mount -t overlay overlay' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq 'generatedMediaSha256' "$REPO_ROOT/Tools/Proxmox/Build-WindowsTemplate.sh"
grep -Fq 'generatedMediaSha256' "$REPO_ROOT/Tools/Proxmox/Certify-WindowsTemplate.sh"
grep -Fq 'qm guest exec' "$REPO_ROOT/Tools/Proxmox/Test-Lab.sh"
if grep -Fq 'ssh -i' "$REPO_ROOT/Tools/Proxmox/Test-Lab.sh"; then
  echo 'Live validation still depends on optional guest SSH.' >&2
  exit 1
fi
if grep -Eqi '(password|secret|credential|token)=[^[]' "$TEMP_DIR"/*.plan; then
  echo 'Potential secret material appeared in a plan.' >&2
  exit 1
fi

echo 'Shell/configuration tests passed.'
