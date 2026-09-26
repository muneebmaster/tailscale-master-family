output "subnet_router_auth_key" {
  description = "Single-use auth key for the subnet router. Retrieve with: terraform output -raw subnet_router_auth_key"
  value       = tailscale_tailnet_key.subnet_router.key
  sensitive   = true
}

output "pihole_auth_key" {
  description = "Single-use auth key for the Pi-hole node. Retrieve with: terraform output -raw pihole_auth_key"
  value       = tailscale_tailnet_key.pihole.key
  sensitive   = true
}

output "pihole_tailscale_ipv4" {
  description = "Pi-hole tailnet address (stage 2 only)."
  value       = local.pihole_tailscale_ipv4
}

output "global_nameserver" {
  description = "Address configured as the tailnet global nameserver (stage 2 only)."
  value       = var.bootstrap_complete ? local.global_nameserver : null
}
