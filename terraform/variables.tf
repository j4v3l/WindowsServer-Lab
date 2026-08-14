variable "proxmox_host" {
  description = "IPv4 address or DNS name of the Proxmox VE API and SSH host."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+$", var.proxmox_host))
    error_message = "proxmox_host must be a plain IPv4 address or DNS name."
  }
}

variable "proxmox_node" {
  description = "Proxmox VE node that owns the lab resources."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.proxmox_node))
    error_message = "proxmox_node contains unsupported characters."
  }
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to the unencrypted private key used for root SSH automation on Proxmox."
  type        = string
}

variable "proxmox_ssh_user" {
  description = "Root SSH account used for Proxmox host-local Packer, preflight, backup, and guest-agent operations."
  type        = string
  default     = "root"

  validation {
    condition     = var.proxmox_ssh_user == "root"
    error_message = "Current Proxmox host-local operations require proxmox_ssh_user = root."
  }
}

variable "site_config_path" {
  description = "Operator-local, non-secret site configuration."
  type        = string
  default     = "../LabConfig/site.json"
}

variable "lab_config_path" {
  description = "Canonical lab inventory."
  type        = string
  default     = "../LabConfig/lab.json"
}

variable "guest_secrets_file" {
  description = "Path to a mode-0600 JSON file containing one-time guest bootstrap passwords; only the path enters Terraform."
  type        = string
  default     = "../LabConfig/secrets.json"
}

variable "setup_keys_file" {
  description = "Optional mode-0600 JSON file containing Microsoft-published installation setup keys."
  type        = string
  default     = ""
}

variable "guest_ssh_public_key_path" {
  description = "Public key injected into guests. Defaults to the .pub companion of proxmox_ssh_private_key_path."
  type        = string
  default     = ""
}

variable "allow_template_rebuild" {
  description = "Safety acknowledgement for a stale, owned Packer template. Leave false for normal applies."
  type        = bool
  default     = false
}
