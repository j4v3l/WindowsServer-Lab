locals {
  site_file = startswith(var.site_config_path, "/") ? var.site_config_path : abspath("${path.module}/${var.site_config_path}")
  lab_file  = startswith(var.lab_config_path, "/") ? var.lab_config_path : abspath("${path.module}/${var.lab_config_path}")
  site      = jsondecode(file(local.site_file))
  lab       = jsondecode(file(local.lab_file))
  vms       = { for vm in local.lab.virtualMachines : vm.name => vm }

  remote_external_script = abspath("${path.module}/../../Tools/Terraform/Remote-External.sh")
  remote_run_script      = abspath("${path.module}/../../Tools/Terraform/Remote-Run.sh")
  guest_payload_files = sort(concat(
    [for file in fileset(abspath("${path.module}/../../Scripts"), "**/*") : abspath("${path.module}/../../Scripts/${file}")],
    [for file in fileset(abspath("${path.module}/../../LabConfig/policies"), "**/*") : abspath("${path.module}/../../LabConfig/policies/${file}")],
    [local.lab_file, abspath("${path.module}/../../Tools/Proxmox/Configure-LabGuests.sh")]
  ))
  guest_payload_digest = sha256(join("", [for file in local.guest_payload_files : "${file}:${filesha256(file)}\n"]))
}

data "external" "lab_preflight" {
  program = [local.remote_external_script]
  query = {
    operation            = "preflight"
    mode                 = "lab"
    host                 = var.proxmox_host
    node                 = var.proxmox_node
    ssh_user             = var.proxmox_ssh_user
    ssh_private_key_path = var.proxmox_ssh_private_key_path
    site_file            = local.site_file
  }
}

resource "terraform_data" "template_revision" {
  for_each = local.vms

  input            = var.template_revisions[each.value.os]
  triggers_replace = [var.template_revisions[each.value.os]]
}

resource "proxmox_virtual_environment_vm" "lab" {
  for_each = local.vms

  node_name   = var.proxmox_node
  vm_id       = each.value.id
  name        = each.value.name
  description = "WindowsServerLab ${each.value.role}; managed by Terraform"
  tags        = sort(["asgard", each.value.role, "terraform", "wslab"])

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]
  on_boot       = true
  started       = local.site.features.startAfterDeploy
  protection    = false

  clone {
    vm_id        = local.site.proxmox.templates[each.value.os]
    node_name    = var.proxmox_node
    datastore_id = local.site.proxmox.vmStorage
    full         = true
    retries      = 3
  }

  agent {
    enabled = true
    timeout = "${local.site.features.guestAgentTimeoutSeconds}s"
    trim    = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memoryMB
    floating  = each.value.balloonMinimumMB
  }

  efi_disk {
    datastore_id      = local.site.proxmox.vmStorage
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  tpm_state {
    datastore_id = local.site.proxmox.vmStorage
    version      = "v2.0"
  }

  disk {
    datastore_id = local.site.proxmox.vmStorage
    interface    = "scsi0"
    file_format  = "raw"
    size         = each.value.diskGB
    cache        = "none"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  dynamic "disk" {
    for_each = try(each.value.dataDisks, [])
    content {
      datastore_id = local.site.proxmox.vmStorage
      interface    = disk.value.slot
      file_format  = "raw"
      size         = disk.value.sizeGB
      cache        = "none"
      discard      = "on"
      iothread     = true
      ssd          = true
    }
  }

  dynamic "network_device" {
    for_each = each.value.nics
    content {
      bridge   = local.site.hostNetworking.bridge
      model    = "virtio"
      firewall = true
      vlan_id  = local.lab.networks[network_device.value.network].vlanId
    }
  }

  initialization {
    datastore_id = local.site.proxmox.vmStorage
    interface    = "ide2"
    upgrade      = false

    dns {
      domain  = local.lab.domain.dnsName
      servers = local.lab.networks.windowsServers.dnsServers
    }

    dynamic "ip_config" {
      for_each = each.value.nics
      content {
        ipv4 {
          address = "${ip_config.value.ipAddress}/${ip_config.value.prefixLength}"
          gateway = ip_config.value.defaultGateway ? local.lab.networks[ip_config.value.network].gateway : null
        }
      }
    }

    user_account {
      username = local.site.guestAccess.user
      keys     = [var.guest_ssh_public_key]
    }
  }

  operating_system {
    type = "win11"
  }

  startup {
    order      = tostring(each.value.bootOrder)
    up_delay   = "30"
    down_delay = "60"
  }

  stop_on_destroy                      = false
  purge_on_destroy                     = true
  delete_unreferenced_disks_on_destroy = true
  reboot_after_update                  = true
  timeout_clone                        = 3600
  timeout_create                       = 3600
  timeout_reboot                       = 1800
  timeout_shutdown_vm                  = 1800
  timeout_start_vm                     = 1800

  lifecycle {
    replace_triggered_by = [terraform_data.template_revision[each.key]]

    precondition {
      condition     = data.external.lab_preflight.result.ready == "true"
      error_message = data.external.lab_preflight.result.message
    }
    precondition {
      condition     = trimspace(var.guest_ssh_public_key) != ""
      error_message = "The guest SSH public key must be non-empty."
    }
  }
}

resource "terraform_data" "guest_configuration" {
  depends_on = [proxmox_virtual_environment_vm.lab, terraform_data.backup_before_destroy]

  triggers_replace = [local.guest_payload_digest]

  lifecycle {
    precondition {
      condition     = fileexists(var.guest_secrets_file)
      error_message = "Copy LabConfig/secrets.example.json to LabConfig/secrets.json, chmod it 600, and set the bootstrap passwords before apply."
    }
  }

  provisioner "local-exec" {
    command = local.remote_run_script
    environment = {
      WSLAB_PROXMOX_HOST                 = var.proxmox_host
      WSLAB_PROXMOX_NODE                 = var.proxmox_node
      WSLAB_PROXMOX_SSH_USER             = var.proxmox_ssh_user
      WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH = var.proxmox_ssh_private_key_path
      WSLAB_REMOTE_OPERATION             = "configure-guests"
      WSLAB_SITE_FILE                    = local.site_file
      WSLAB_GUEST_SECRETS_FILE           = var.guest_secrets_file
    }
  }
}

resource "terraform_data" "backup_before_destroy" {
  depends_on = [proxmox_virtual_environment_vm.lab]

  triggers_replace = [
    sha256(file(local.lab_file)),
    sha256(jsonencode({
      node       = var.proxmox_node
      storage    = local.site.proxmox.vmStorage
      templates  = local.site.proxmox.templates
      bridge     = local.site.hostNetworking.bridge
      backup     = local.site.proxmox.backupStorage
      retention  = local.site.proxmox.backupRetention
      backupGate = local.site.features.backupBeforeDestroy
      revisions  = var.template_revisions
    })),
  ]

  input = {
    host                 = var.proxmox_host
    inventory_json       = jsonencode([for vm in values(local.vms) : { id = vm.id, name = vm.name, role = vm.role }])
    node                 = var.proxmox_node
    ssh_user             = var.proxmox_ssh_user
    ssh_private_key_path = var.proxmox_ssh_private_key_path
    remote_run_script    = local.remote_run_script
    site_file            = local.site_file
  }

  provisioner "local-exec" {
    when       = destroy
    command    = self.input.remote_run_script
    on_failure = fail
    environment = {
      WSLAB_PROXMOX_HOST                 = self.input.host
      WSLAB_PROXMOX_NODE                 = self.input.node
      WSLAB_PROXMOX_SSH_USER             = self.input.ssh_user
      WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH = self.input.ssh_private_key_path
      WSLAB_REMOTE_OPERATION             = "backup-lab"
      WSLAB_BACKUP_INVENTORY_JSON        = self.input.inventory_json
      WSLAB_SITE_FILE                    = self.input.site_file
    }
  }
}
