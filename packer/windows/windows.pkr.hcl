packer {
  required_version = ">= 1.10.0"
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "= 1.2.3"
    }
  }
}

variable "proxmox_url" { type = string }
variable "proxmox_username" { type = string }
variable "proxmox_token" {
  type      = string
  sensitive = true
}
variable "windows_password" {
  type      = string
  sensitive = true
}
variable "cloudbase_msi_url" { type = string }
variable "cloudbase_msi_sha256" { type = string }
variable "node" { type = string }
variable "vm_id" { type = number }
variable "storage_pool" { type = string }
variable "build_bridge" { type = string }
variable "build_ipv4_address" { type = string }
variable "build_run_id" { type = string }
variable "iso_file" { type = string }
variable "iso_sha256" { type = string }
variable "virtio_iso" { type = string }
variable "virtio_iso_sha256" { type = string }
variable "os_type" {
  type = string
  validation {
    condition     = contains(["server-2025", "server-2022", "windows-11"], var.os_type)
    error_message = "The os_type value must be server-2025, server-2022, or windows-11."
  }
}

locals {
  is_client     = var.os_type == "windows-11"
  template_name = "wslab-${var.os_type}"
  disk_size     = local.is_client ? "80G" : "64G"
  memory        = local.is_client ? 4096 : 6144
  cores         = local.is_client ? 2 : 4
  image_selector_key = {
    "server-2025" = "/IMAGE/INDEX"
    "server-2022" = "/IMAGE/INDEX"
    "windows-11"  = "/IMAGE/NAME"
  }[var.os_type]
  image_selector_value = {
    "server-2025" = "2"
    "server-2022" = "2"
    "windows-11"  = "Windows 11 Education"
  }[var.os_type]
  virtio_driver_path = var.os_type == "server-2022" ? "2k22" : (var.os_type == "server-2025" ? "2k25" : "w11")
}

source "proxmox-iso" "windows" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = false
  node                     = var.node
  vm_id                    = var.vm_id
  vm_name                  = local.template_name
  template_name            = local.template_name
  template_description     = "WindowsServerLab v2 ${var.os_type}; WSLAB-BUILD-RUN=${var.build_run_id}; Cloudbase-Init and QEMU Guest Agent; certification required"
  tags                     = "wslab;wslab-build"

  boot_iso {
    type         = "sata"
    iso_file     = var.iso_file
    iso_checksum = "sha256:${var.iso_sha256}"
    unmount      = true
  }
  qemu_agent      = true
  os              = "win11"
  bios            = "ovmf"
  machine         = "q35"
  cores           = local.cores
  memory          = local.memory
  cpu_type        = "host"
  scsi_controller = "virtio-scsi-single"

  efi_config {
    efi_storage_pool  = var.storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  tpm_config {
    tpm_storage_pool = var.storage_pool
    tpm_version      = "v2.0"
  }

  disks {
    disk_size    = local.disk_size
    storage_pool = var.storage_pool
    type         = "scsi"
    format       = "raw"
    io_thread    = true
  }

  network_adapters {
    model    = "virtio"
    bridge   = var.build_bridge
    firewall = true
  }

  additional_iso_files {
    type         = "sata"
    iso_file     = var.virtio_iso
    iso_checksum = "sha256:${var.virtio_iso_sha256}"
    unmount      = true
  }

  communicator   = "winrm"
  winrm_host     = var.build_ipv4_address
  winrm_username = "LabBootstrap"
  winrm_password = var.windows_password
  winrm_timeout  = "2h"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_use_ntlm = false
  winrm_port     = 5986
  # The Microsoft media's UEFI "press any key" window expires before the
  # plugin's 10-second default on current PVE/QEMU. Send several early keys.
  boot_wait    = "3s"
  boot_command = ["<spacebar><wait1><spacebar><wait1><spacebar><wait1><spacebar><wait1><spacebar><wait1><spacebar>"]
}

build {
  sources = ["source.proxmox-iso.windows"]

  provisioner "file" {
    source      = "${path.root}/../../Scripts"
    destination = "C:\\ProgramData\\WindowsServerLab"
  }

  provisioner "file" {
    source      = "${path.root}/../../LabConfig/demos"
    destination = "C:\\ProgramData\\WindowsServerLab\\LabConfig"
  }

  provisioner "file" {
    source      = "${path.root}/../../LabConfig/policies"
    destination = "C:\\ProgramData\\WindowsServerLab\\LabConfig"
  }

  provisioner "file" {
    source      = "${path.root}/seal-template.ps1"
    destination = "C:\\ProgramData\\WindowsServerLab\\seal-template.ps1"
  }

  provisioner "file" {
    source      = "${path.root}/first-boot-cleanup.ps1"
    destination = "C:\\ProgramData\\WindowsServerLab\\first-boot-cleanup.ps1"
  }

  provisioner "powershell" {
    script = "${path.root}/prepare-template.ps1"
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    script  = "${path.root}/finalize-template.ps1"
    timeout = "30m"
  }

  provisioner "shell-local" {
    environment_vars = [
      "WSLAB_TEMPLATE_ID=${var.vm_id}",
      "WSLAB_SHUTDOWN_TIMEOUT_SECONDS=3600"
    ]
    script = "${path.root}/wait-for-template-shutdown.sh"
  }
}
