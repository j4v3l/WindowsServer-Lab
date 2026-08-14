locals {
  site_file = startswith(var.site_config_path, "/") ? var.site_config_path : abspath("${path.module}/${var.site_config_path}")
  lab_file  = startswith(var.lab_config_path, "/") ? var.lab_config_path : abspath("${path.module}/${var.lab_config_path}")
  site      = jsondecode(file(local.site_file))
  lab       = jsondecode(file(local.lab_file))

  shared_management_bridge = local.site.hostNetworking.sharedManagementBridge

  setup_keys_file = var.setup_keys_file == "" ? "" : (
    startswith(var.setup_keys_file, "/") ? var.setup_keys_file : abspath("${path.module}/${var.setup_keys_file}")
  )
  remote_external_script = abspath("${path.module}/../../Tools/Terraform/Remote-External.sh")
  remote_run_script      = abspath("${path.module}/../../Tools/Terraform/Remote-Run.sh")
}

data "external" "foundation_preflight" {
  program = [local.remote_external_script]
  query = {
    operation            = "preflight"
    mode                 = "foundation"
    host                 = var.proxmox_host
    node                 = var.proxmox_node
    ssh_user             = var.proxmox_ssh_user
    ssh_private_key_path = var.proxmox_ssh_private_key_path
    site_file            = local.site_file
  }
}

data "external" "server_2025_template" {
  program = [local.remote_external_script]
  query = {
    operation            = "template-status"
    os                   = "server-2025"
    host                 = var.proxmox_host
    node                 = var.proxmox_node
    ssh_user             = var.proxmox_ssh_user
    ssh_private_key_path = var.proxmox_ssh_private_key_path
    site_file            = local.site_file
  }
}

resource "terraform_data" "server_2025_template" {
  depends_on       = [terraform_data.foundation_guard, proxmox_network_linux_bridge.lab]
  triggers_replace = [data.external.server_2025_template.result.input_digest]

  lifecycle {
    precondition {
      condition     = contains(["absent", "current", "interrupted"], data.external.server_2025_template.result.status) || (data.external.server_2025_template.result.status == "stale" && var.allow_template_rebuild)
      error_message = "Server 2025 template is stale or unowned. Use Tools/Terraform/Rebuild-Templates.sh only for a stale owned template; resolve an unowned template ID manually."
    }
  }

  provisioner "local-exec" {
    command = local.remote_run_script
    environment = {
      WSLAB_PROXMOX_HOST                 = var.proxmox_host
      WSLAB_PROXMOX_NODE                 = var.proxmox_node
      WSLAB_PROXMOX_SSH_USER             = var.proxmox_ssh_user
      WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH = var.proxmox_ssh_private_key_path
      WSLAB_REMOTE_OPERATION             = "reconcile-template"
      WSLAB_ALLOW_TEMPLATE_REBUILD       = tostring(var.allow_template_rebuild)
      WSLAB_TEMPLATE_OS                  = "server-2025"
      WSLAB_SETUP_KEYS_FILE              = local.setup_keys_file
      WSLAB_SITE_FILE                    = local.site_file
    }
  }
}

data "external" "windows_11_template" {
  program = [local.remote_external_script]
  query = {
    operation            = "template-status"
    os                   = "windows-11"
    host                 = var.proxmox_host
    node                 = var.proxmox_node
    ssh_user             = var.proxmox_ssh_user
    ssh_private_key_path = var.proxmox_ssh_private_key_path
    site_file            = local.site_file
  }
}

resource "terraform_data" "foundation_guard" {
  lifecycle {
    precondition {
      condition     = data.external.foundation_preflight.result.ready == "true"
      error_message = data.external.foundation_preflight.result.message
    }
    precondition {
      condition     = contains(["absent", "current", "interrupted"], data.external.server_2025_template.result.status) || (data.external.server_2025_template.result.status == "stale" && var.allow_template_rebuild)
      error_message = "Server 2025 template is stale or unowned. Use Tools/Terraform/Rebuild-Templates.sh only for a stale owned template; resolve an unowned template ID manually."
    }
    precondition {
      condition     = contains(["absent", "current", "interrupted"], data.external.windows_11_template.result.status) || (data.external.windows_11_template.result.status == "stale" && var.allow_template_rebuild)
      error_message = "Windows 11 template is stale or unowned. Use Tools/Terraform/Rebuild-Templates.sh only for a stale owned template; resolve an unowned template ID manually."
    }
  }
}

resource "terraform_data" "windows_11_template" {
  depends_on       = [terraform_data.server_2025_template]
  triggers_replace = [data.external.windows_11_template.result.input_digest]

  lifecycle {
    precondition {
      condition     = contains(["absent", "current", "interrupted"], data.external.windows_11_template.result.status) || (data.external.windows_11_template.result.status == "stale" && var.allow_template_rebuild)
      error_message = "Windows 11 template is stale or unowned. Use Tools/Terraform/Rebuild-Templates.sh only for a stale owned template; resolve an unowned template ID manually."
    }
  }

  provisioner "local-exec" {
    command = local.remote_run_script
    environment = {
      WSLAB_PROXMOX_HOST                 = var.proxmox_host
      WSLAB_PROXMOX_NODE                 = var.proxmox_node
      WSLAB_PROXMOX_SSH_USER             = var.proxmox_ssh_user
      WSLAB_PROXMOX_SSH_PRIVATE_KEY_PATH = var.proxmox_ssh_private_key_path
      WSLAB_REMOTE_OPERATION             = "reconcile-template"
      WSLAB_ALLOW_TEMPLATE_REBUILD       = tostring(var.allow_template_rebuild)
      WSLAB_TEMPLATE_OS                  = "windows-11"
      WSLAB_SETUP_KEYS_FILE              = local.setup_keys_file
      WSLAB_SITE_FILE                    = local.site_file
    }
  }
}

resource "proxmox_network_linux_bridge" "lab" {
  count = local.shared_management_bridge ? 0 : 1

  node_name = var.proxmox_node
  name      = local.site.hostNetworking.bridge
  ports     = [local.site.hostNetworking.uplink]
  autostart = true

  vlan_aware = true
  vids       = join(" ", [for vlan in local.site.hostNetworking.allowedVlans : tostring(vlan)])
  comment    = "WindowsServerLab Terraform; unnumbered VLAN 90/100 trunk"

  depends_on = [terraform_data.foundation_guard]

}
