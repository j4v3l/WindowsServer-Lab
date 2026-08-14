locals {
  site_file = startswith(var.site_config_path, "/") ? var.site_config_path : abspath("${path.root}/${var.site_config_path}")
  lab_file  = startswith(var.lab_config_path, "/") ? var.lab_config_path : abspath("${path.root}/${var.lab_config_path}")

  ssh_private_key_path = pathexpand(var.proxmox_ssh_private_key_path)
  guest_public_key_path = pathexpand(
    var.guest_ssh_public_key_path != "" ? var.guest_ssh_public_key_path : "${var.proxmox_ssh_private_key_path}.pub"
  )
  guest_secrets_file = startswith(var.guest_secrets_file, "/") ? var.guest_secrets_file : abspath("${path.root}/${var.guest_secrets_file}")
  setup_keys_file = var.setup_keys_file == "" ? "" : (
    startswith(var.setup_keys_file, "/") ? var.setup_keys_file : abspath("${path.root}/${var.setup_keys_file}")
  )
  guest_ssh_public_key = fileexists(local.guest_public_key_path) ? trimspace(file(local.guest_public_key_path)) : ""
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/"
  insecure = false
}

module "foundation" {
  source = "./foundation"

  site_config_path             = local.site_file
  lab_config_path              = local.lab_file
  proxmox_host                 = var.proxmox_host
  proxmox_node                 = var.proxmox_node
  proxmox_ssh_user             = var.proxmox_ssh_user
  proxmox_ssh_private_key_path = local.ssh_private_key_path
  setup_keys_file              = local.setup_keys_file
  allow_template_rebuild       = var.allow_template_rebuild
}

module "lab" {
  source = "./lab"

  site_config_path             = local.site_file
  lab_config_path              = local.lab_file
  proxmox_host                 = var.proxmox_host
  proxmox_node                 = var.proxmox_node
  proxmox_ssh_user             = var.proxmox_ssh_user
  proxmox_ssh_private_key_path = local.ssh_private_key_path
  guest_secrets_file           = local.guest_secrets_file
  guest_ssh_public_key         = local.guest_ssh_public_key
  template_revisions = {
    server-2025 = module.foundation.templates.server_2025.revision
    windows-11  = module.foundation.templates.windows_11.revision
  }

  depends_on = [module.foundation]
}

check "local_automation_inputs" {
  assert {
    condition     = fileexists(local.ssh_private_key_path)
    error_message = "proxmox_ssh_private_key_path must name a readable local private key."
  }
  assert {
    condition     = local.guest_ssh_public_key != ""
    error_message = "The guest SSH public key must exist and be non-empty."
  }
  assert {
    condition     = fileexists(local.guest_secrets_file)
    error_message = "Copy LabConfig/secrets.example.json to LabConfig/secrets.json, chmod it 600, and set the bootstrap passwords before apply."
  }
}
