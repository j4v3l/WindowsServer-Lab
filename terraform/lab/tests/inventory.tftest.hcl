mock_provider "proxmox" {}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        ready   = "true"
        message = "mocked preflight passed"
      }
    }
  }
}

variables {
  site_config_path             = "../../Tests/Fixtures/site.terraform-test.json"
  proxmox_host                 = "192.0.2.50"
  proxmox_node                 = "pve01"
  proxmox_ssh_private_key_path = "../../Tests/Fixtures/terraform-test.key"
  guest_secrets_file           = "../../Tests/Fixtures/site.terraform-test.json"
  guest_ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnlyKeyMaterial terraform-test"
  template_revisions           = { server-2025 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", windows-11 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
}

run "six_machine_plan" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_vm.lab) == 6
    error_message = "Terraform must create exactly six VMs."
  }

  assert {
    condition     = length([for vm in values(local.vms) : vm if vm.os == "server-2025"]) == 5 && length([for vm in values(local.vms) : vm if vm.os == "windows-11"]) == 1
    error_message = "The lab must contain five Server 2025 VMs and one Windows 11 VM."
  }

  assert {
    condition     = length(toset([for vm in values(local.vms) : vm.id])) == 6 && length(toset([for vm in values(local.vms) : vm.name])) == 6 && length(toset(flatten([for vm in values(local.vms) : [for nic in vm.nics : nic.ipAddress]]))) == 6
    error_message = "VM IDs, names, and IP addresses must be unique."
  }

  assert {
    condition = alltrue([
      for vm in values(local.vms) :
      vm.os != "server-2025" || (
        vm.nics[0].network == "windowsServers" &&
        local.lab.networks[vm.nics[0].network].vlanId == 90 &&
        local.lab.networks[vm.nics[0].network].cidr == "192.168.90.0/24" &&
        local.lab.networks[vm.nics[0].network].gateway == "192.168.90.1"
      )
    ])
    error_message = "Every Windows server must use VLAN 90 and the 192.168.90.0/24 gateway."
  }

  assert {
    condition = alltrue([
      for vm in values(local.vms) :
      vm.os != "windows-11" || (
        vm.nics[0].network == "windowsClients" &&
        local.lab.networks[vm.nics[0].network].vlanId == 100 &&
        local.lab.networks[vm.nics[0].network].cidr == "192.168.100.0/24" &&
        local.lab.networks[vm.nics[0].network].gateway == "192.168.100.1"
      )
    ])
    error_message = "The Windows client must use VLAN 100 and the 192.168.100.0/24 gateway."
  }

  assert {
    condition = alltrue([
      for name, vm in proxmox_virtual_environment_vm.lab :
      vm.clone[0].vm_id == (local.vms[name].os == "server-2025" ? 9000 : 9011)
    ])
    error_message = "Each VM must clone from the matching Server 2025 or Windows 11 template."
  }

  assert {
    condition = alltrue([
      for vm in proxmox_virtual_environment_vm.lab :
      length(vm.network_device) == 1 && vm.network_device[0].bridge == "vmbr0" && contains([90, 100], vm.network_device[0].vlan_id)
    ])
    error_message = "Every VM must use one tagged NIC on the validated shared vmbr0 trunk."
  }

  assert {
    condition = alltrue([
      for vm in proxmox_virtual_environment_vm.lab :
      vm.bios == "ovmf" && vm.machine == "q35" && vm.efi_disk[0].pre_enrolled_keys && vm.tpm_state[0].version == "v2.0" && vm.agent[0].enabled
    ])
    error_message = "Secure Boot, TPM 2.0, q35/OVMF, and the guest agent must be enabled."
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.lab["HEIMDALL-FS01"].disk) == 2 && proxmox_virtual_environment_vm.lab["HEIMDALL-FS01"].disk[1].size == 56
    error_message = "HEIMDALL-FS01 must have its 56 GB data disk."
  }

  assert {
    condition = alltrue([
      for name, vm in proxmox_virtual_environment_vm.lab :
      tonumber(vm.startup[0].order) == local.vms[name].bootOrder &&
      !vm.stop_on_destroy && vm.purge_on_destroy && vm.delete_unreferenced_disks_on_destroy &&
      vm.tags == sort(["asgard", local.vms[name].role, "terraform", "wslab"])
    ])
    error_message = "Startup order, ownership tags, and destruction settings must be explicit."
  }
}

run "reject_insufficient_capacity" {
  command = plan

  override_data {
    target = data.external.lab_preflight
    values = {
      result = {
        ready   = "false"
        message = "Insufficient CPU, RAM, or storage capacity."
      }
    }
  }

  expect_failures = [proxmox_virtual_environment_vm.lab]
}

run "reject_stale_certification" {
  command = plan

  override_data {
    target = data.external.lab_preflight
    values = {
      result = {
        ready   = "false"
        message = "Template certification is stale."
      }
    }
  }

  expect_failures = [proxmox_virtual_environment_vm.lab]
}

run "reject_duplicate_resources" {
  command = plan

  override_data {
    target = data.external.lab_preflight
    values = {
      result = {
        ready   = "false"
        message = "A requested VM ID, name, or address already exists."
      }
    }
  }

  expect_failures = [proxmox_virtual_environment_vm.lab]
}

run "reject_invalid_networking" {
  command = plan

  override_data {
    target = data.external.lab_preflight
    values = {
      result = {
        ready   = "false"
        message = "The bridge or VLAN topology is not ready."
      }
    }
  }

  expect_failures = [proxmox_virtual_environment_vm.lab]
}
