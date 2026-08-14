# Terraform startup and acceptance

## 1. Prepare local inputs

Run from an operator workstation that can reach the Proxmox API and SSH service. Verify the host key before automation (`ssh root@192.168.10.50` once, inspect the fingerprint, then exit).

```bash
cp LabConfig/site.example.json LabConfig/site.json
cp LabConfig/secrets.example.json LabConfig/secrets.json
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
chmod 600 LabConfig/site.json LabConfig/secrets.json terraform/terraform.tfvars
```

`terraform.tfvars` identifies the Proxmox host, node, and SSH private-key path. In `site.json`, set the storage IDs, verified Windows/VirtIO media volumes and SHA-256 digests, physical uplink, unused template build/canary addresses, report paths, and backup storage. In ignored `secrets.json`, replace every placeholder with a strong unique password.

The default shared-uplink design expects existing `vmbr0` to keep the Proxmox management address/default route and to carry tagged VLANs 90 and 100. The upstream router owns `192.168.90.1` and `192.168.100.1` and permits required client-to-AD traffic. Terraform validates shared management networking but will not risk rewriting it. For an unused dedicated uplink, set `sharedManagementBridge` false and a non-`vmbr0` bridge; Terraform then creates that bridge.

```bash
Tools/Proxmox/Validate-LabConfig.sh --site LabConfig/site.json
```

## 2. Plan and apply everything

Provider credentials stay in the environment. The token should have only the permissions required by the declared resources.

```bash
export PROXMOX_VE_API_TOKEN='terraform@pve!provider=REDACTED'
umask 077
terraform -chdir=terraform init
terraform -chdir=terraform plan -out=lab.tfplan
terraform -chdir=terraform apply lab.tfplan
```

The one apply performs remote bridge and capacity preflight, builds/certifies absent templates through Packer, creates every inventory VM, waits for QEMU Guest Agent, and converges AD/DNS/DHCP, joins, IIS, WEF, LAPS, security baselines, and file/access policy. Remote runtime directories and the copied password file are removed after each operation.

Packer renders both Server 2025 Standard and Windows 11 Education media with the corresponding Microsoft-published KMS client setup key and `WillShowUI=Never`. The keys prevent the licensing-method prompt during Setup but do not activate Windows or provide an entitlement.

Ordinary apply refuses a stale or unowned template. For a stale owned template, use the exact confirmation printed for that template:

```bash
Tools/Terraform/Rebuild-Templates.sh --site LabConfig/site.json \
  --os windows-11 --confirm rebuild-windows-11-9011
```

## 3. Accept the lab

Product-key activation is optional and remains outside creation state. Run activation and live acceptance on the Proxmox node, where the QEMU Guest Agent command is available:

```bash
sudo Tools/Proxmox/Activate-LabGuests.sh --site LabConfig/site.json --action activate --apply
sudo Tools/Proxmox/Test-Lab.sh --site LabConfig/site.json --phase full
```

Retain the JSON/JUnit evidence from the configured report directory. Finally, require a zero-change plan (exit code 0):

```bash
terraform -chdir=terraform plan -detailed-exitcode
```
