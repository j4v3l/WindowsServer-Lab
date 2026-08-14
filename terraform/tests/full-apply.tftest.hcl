mock_provider "proxmox" {}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        ready        = "true"
        message      = "mocked remote preflight passed"
        status       = "current"
        input_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }
    }
  }
}

variables {
  proxmox_host                 = "192.168.10.50"
  proxmox_node                 = "pve2"
  proxmox_ssh_private_key_path = "../Tests/Fixtures/terraform-test.pub"
  guest_ssh_public_key_path    = "../Tests/Fixtures/terraform-test.pub"
  guest_secrets_file           = "../Tests/Fixtures/site.terraform-test.json"
  site_config_path             = "../Tests/Fixtures/site.terraform-test.json"
}

run "single_full_apply_plan" {
  command = plan

  assert {
    condition     = length(module.lab.virtual_machines) == 6
    error_message = "The single root must pass all six canonical inventory VMs to the lab module."
  }

  assert {
    condition     = module.foundation.bridge.name == "vmbr0" && module.foundation.bridge.shared_management
    error_message = "The single root must include foundation bridge validation."
  }

  assert {
    condition     = module.foundation.templates.server_2025.id == 9000 && module.foundation.templates.windows_11.id == 9011
    error_message = "The single root must include both Packer template reconciliation resources."
  }
}
