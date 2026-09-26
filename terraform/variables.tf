variable "tailnet" {
  description = "Tailnet name. \"-\" selects the default tailnet of the credential."
  type        = string
  default     = "-"
}

variable "admin_emails" {
  description = "Login identities with full administrative access."
  type        = list(string)

  validation {
    condition     = length(var.admin_emails) > 0
    error_message = "At least one admin identity is required."
  }
}

variable "family_emails" {
  description = "Login identities for family members (print, NAS, DNS access)."
  type        = list(string)

  validation {
    condition     = length(var.family_emails) > 0
    error_message = "At least one family identity is required (used by policy tests)."
  }
}

variable "lan_cidr" {
  description = "Home LAN advertised by the subnet router."
  type        = string
  default     = "192.168.0.0/24"

  validation {
    condition     = can(cidrhost(var.lan_cidr, 0))
    error_message = "lan_cidr must be a valid IPv4 CIDR."
  }
}

variable "subnet_router_lan_ip" {
  description = "LAN address of the subnet router (documentation and outputs)."
  type        = string
  default     = "192.168.0.253"
}

variable "pihole_lan_ip" {
  description = "LAN address of the Pi-hole node."
  type        = string
  default     = "192.168.0.254"
}

variable "nas_ip" {
  description = "LAN address of the Synology NAS."
  type        = string
  default     = "192.168.0.252"
}

variable "printer_ip" {
  description = "LAN address of the Canon printer."
  type        = string
  default     = "192.168.0.250"
}

variable "subnet_router_hostname" {
  description = "Tailscale hostname of the subnet router."
  type        = string
  default     = "rpi-subnet-router"
}

variable "pihole_hostname" {
  description = "Tailscale hostname of the Pi-hole node."
  type        = string
  default     = "rpi-pihole"
}

variable "ssh_check_period" {
  description = "How often Tailscale SSH check mode re-prompts for authentication."
  type        = string
  default     = "12h"
}

variable "dns_nameserver_mode" {
  description = "Address used for the tailnet global nameserver: \"tailscale\" (Pi-hole 100.x IP) or \"lan\" (pihole_lan_ip)."
  type        = string
  default     = "tailscale"

  validation {
    condition     = contains(["tailscale", "lan"], var.dns_nameserver_mode)
    error_message = "dns_nameserver_mode must be \"tailscale\" or \"lan\"."
  }
}

variable "bootstrap_complete" {
  description = "Set to true after both Raspberry Pis have joined the tailnet (stage 2)."
  type        = bool
  default     = false
}
