variable "site_config_path" {
  description = "Path to the operator-local site.json, relative to this root or absolute."
  type        = string
  default     = "../../LabConfig/site.json"
}

variable "lab_config_path" {
  description = "Path to the canonical inventory-driven lab definition, relative to this root or absolute."
  type        = string
  default     = "../../LabConfig/lab.json"
}

variable "proxmox_host" {
  description = "Proxmox API and SSH host."
  type        = string
}

variable "proxmox_node" {
  description = "Target Proxmox node."
  type        = string
}

variable "proxmox_ssh_user" {
  description = "SSH account used for host-local automation."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Expanded path to the Proxmox SSH private key."
  type        = string
}

variable "guest_secrets_file" {
  description = "Local path to the ignored guest bootstrap secret file."
  type        = string
}

variable "guest_ssh_public_key" {
  description = "Public key injected into each Windows guest."
  type        = string
}

variable "template_revisions" {
  description = "Certified Packer input revision for each guest OS; a revision change rotates dependent full clones."
  type        = map(string)

  validation {
    condition = (
      length(var.template_revisions) == 2 &&
      contains(keys(var.template_revisions), "server-2025") &&
      contains(keys(var.template_revisions), "windows-11") &&
      alltrue([for revision in values(var.template_revisions) : can(regex("^[a-f0-9]{64}$", revision))])
    )
    error_message = "template_revisions must contain one lowercase SHA-256 digest for server-2025 and windows-11."
  }
}
