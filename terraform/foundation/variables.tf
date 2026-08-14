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

variable "setup_keys_file" {
  description = "Optional root-only JSON file containing Microsoft-published setup keys."
  type        = string
  default     = ""
}

variable "allow_template_rebuild" {
  description = "One-run destructive acknowledgement used only by the confirmed template rebuild wrapper."
  type        = bool
  default     = false
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
