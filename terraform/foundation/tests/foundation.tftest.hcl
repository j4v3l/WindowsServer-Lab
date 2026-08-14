mock_provider "proxmox" {}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        ready        = "true"
        message      = "mocked preflight passed"
        status       = "current"
        input_digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      }
    }
  }
}

variables {
  site_config_path             = "../../Tests/Fixtures/site.terraform-test.json"
  proxmox_host                 = "192.0.2.50"
  proxmox_node                 = "pve01"
  proxmox_ssh_private_key_path = "../../Tests/Fixtures/terraform-test.key"
}

run "shared_management_foundation" {
  command = plan

  assert {
    condition     = length(proxmox_network_linux_bridge.lab) == 0
    error_message = "Foundation must not take Terraform ownership of the shared management bridge."
  }

  assert {
    condition = (
      output.bridge.name == "vmbr0" &&
      output.bridge.uplink == "nic0" &&
      output.bridge.allowed_vlans == [90, 100] &&
      output.bridge.shared_management &&
      !output.bridge.managed_by_terraform &&
      output.bridge.host_addressed
    )
    error_message = "Foundation must expose the externally managed shared vmbr0 trunk."
  }

  assert {
    condition     = output.templates.server_2025.id == 9000 && output.templates.windows_11.id == 9011
    error_message = "Foundation must retain the two canonical template IDs."
  }
}

run "reject_invalid_shared_management_mapping" {
  command = plan

  override_data {
    target = data.external.foundation_preflight
    values = {
      result = {
        ready   = "false"
        message = "Shared-uplink mode requires vmbr0 to own the default route."
      }
    }
  }

  expect_failures = [terraform_data.foundation_guard]
}

run "reject_missing_uplink_carrier" {
  command = plan

  override_data {
    target = data.external.foundation_preflight
    values = {
      result = {
        ready   = "false"
        message = "Configured management uplink nic0 has no carrier."
      }
    }
  }

  expect_failures = [terraform_data.foundation_guard]
}

run "reject_wrong_shared_bridge_uplink" {
  command = plan

  override_data {
    target = data.external.foundation_preflight
    values = {
      result = {
        ready   = "false"
        message = "Shared vmbr0 does not own configured uplink nic0."
      }
    }
  }

  expect_failures = [terraform_data.foundation_guard]
}

run "reject_invalid_vlan_trunk" {
  command = plan

  override_data {
    target = data.external.foundation_preflight
    values = {
      result = {
        ready   = "false"
        message = "Existing lab trunk does not expose VLANs 90 and 100."
      }
    }
  }

  expect_failures = [terraform_data.foundation_guard]
}

run "reject_stale_server_template" {
  command = plan

  override_data {
    target = data.external.server_2025_template
    values = {
      result = {
        status       = "stale"
        input_digest = "mocked-stale-template-digest"
        message      = "Template certification is stale."
      }
    }
  }

  expect_failures = [terraform_data.foundation_guard]
}
