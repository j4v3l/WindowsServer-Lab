output "bridge" {
  description = "Validated bridge used by both lab VLANs and its ownership mode."
  value = {
    name                 = local.site.hostNetworking.bridge
    uplink               = local.site.hostNetworking.uplink
    allowed_vlans        = local.site.hostNetworking.allowedVlans
    shared_management    = local.shared_management_bridge
    managed_by_terraform = !local.shared_management_bridge
    host_addressed       = local.shared_management_bridge
  }
}

output "templates" {
  description = "Durable template IDs and their certification state at plan time."
  value = {
    server_2025 = {
      id       = local.site.proxmox.templates["server-2025"]
      status   = data.external.server_2025_template.result.status
      revision = data.external.server_2025_template.result.input_digest
    }
    windows_11 = {
      id       = local.site.proxmox.templates["windows-11"]
      status   = data.external.windows_11_template.result.status
      revision = data.external.windows_11_template.result.input_digest
    }
  }
}
