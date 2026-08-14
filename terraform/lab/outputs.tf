output "virtual_machines" {
  description = "Canonical identity and network assignment for every managed VM."
  value = {
    for name, vm in proxmox_virtual_environment_vm.lab : name => {
      id      = vm.vm_id
      role    = local.vms[name].role
      os      = local.vms[name].os
      address = local.vms[name].nics[0].ipAddress
      vlan_id = local.lab.networks[local.vms[name].nics[0].network].vlanId
    }
  }
}

output "networks" {
  value = {
    windows_servers = local.lab.networks.windowsServers
    windows_clients = local.lab.networks.windowsClients
  }
}

output "template_ids" {
  value = local.site.proxmox.templates
}
