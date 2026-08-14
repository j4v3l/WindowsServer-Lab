terraform {
  required_version = ">= 1.15.0, < 1.16.0"

  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "= 2.4.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.111.1"
    }
  }
}
