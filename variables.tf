# variables.tf

variable "proxmox_api_url" {
  type        = string
  description = "The URL for the Proxmox API (e.g., https://pve.example.com:8006/api2/json)."
  sensitive   = true
}

variable "proxmox_api_token_id" {
  type        = string
  description = "The Proxmox API token ID (e.g., terraform@pve!my-token)."
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "The secret for the Proxmox API token."
  sensitive   = true
}

variable "proxmox_node_name" {
  type        = string
  description = "The name of the Proxmox node to scan for LXCs."
}

variable "proxmox_ssh_host" {
  type        = string
  description = "The IP address or hostname of the Proxmox host for SSH."
}

variable "proxmox_ssh_user" {
  type        = string
  description = "The username for SSHing into the Proxmox host (e.g., root)."
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  type        = string
  description = "Path to the SSH private key for connecting to the Proxmox host."
  default     = "~/.ssh/id_rsa"
}

variable "max_parallel" {
  description = "Max parallel LXC updates to run on the host"
  type        = number
  default     = 8
}
