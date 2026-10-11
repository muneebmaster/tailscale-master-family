locals {
  policy = templatefile("${path.module}/policy.hujson", {
    admins           = jsonencode(var.admin_emails)
    family           = jsonencode(var.family_emails)
    test_admin       = var.admin_emails[0]
    test_member      = var.family_emails[0]
    lan_cidr         = var.lan_cidr
    printer_ip       = var.printer_ip
    nas_ip           = var.nas_ip
    pihole_lan_ip    = var.pihole_lan_ip
    ssh_check_period = var.ssh_check_period
  })
}

# ---------------------------------------------------------------------------
# Stage 1: tailnet policy and bootstrap auth keys
# ---------------------------------------------------------------------------

resource "tailscale_acl" "policy" {
  acl                        = local.policy
  overwrite_existing_content = true
}

resource "tailscale_tailnet_key" "subnet_router" {
  description         = "bootstrap ${var.subnet_router_hostname}"
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  expiry              = 3600
  tags                = ["tag:subnet-router"]
  recreate_if_invalid = "never"

  depends_on = [tailscale_acl.policy]
}

resource "tailscale_tailnet_key" "pihole" {
  description         = "bootstrap ${var.pihole_hostname}"
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  expiry              = 3600
  tags                = ["tag:dns"]
  recreate_if_invalid = "never"

  depends_on = [tailscale_acl.policy]
}

# ---------------------------------------------------------------------------
# Stage 2: device lookups, route pinning, Pi-hole as tailnet DNS
# ---------------------------------------------------------------------------

data "tailscale_device" "subnet_router" {
  count    = var.bootstrap_complete ? 1 : 0
  hostname = var.subnet_router_hostname
  wait_for = "60s"
}

data "tailscale_device" "pihole" {
  count    = var.bootstrap_complete ? 1 : 0
  hostname = var.pihole_hostname
  wait_for = "60s"
}

# autoApprovers already approves the route; this pins it declaratively so
# drift (someone disabling the route in the console) shows up in plan.
resource "tailscale_device_subnet_routes" "home_lan" {
  count     = var.bootstrap_complete ? 1 : 0
  device_id = data.tailscale_device.subnet_router[0].node_id
  routes    = [var.lan_cidr]
}

locals {
  pihole_tailscale_ipv4 = var.bootstrap_complete ? one([
    for addr in data.tailscale_device.pihole[0].addresses : addr if !strcontains(addr, ":")
  ]) : null

  global_nameserver = var.dns_nameserver_mode == "tailscale" ? local.pihole_tailscale_ipv4 : var.pihole_lan_ip
}

resource "tailscale_dns_configuration" "dns" {
  magic_dns          = true
  override_local_dns = var.bootstrap_complete

  # With local DNS overridden, clients no longer get the home DHCP suffix, so
  # push it as a search domain: "vault" then resolves as "vault.lan".
  search_paths = [var.dns_search_domain]

  dynamic "nameservers" {
    for_each = var.bootstrap_complete ? [local.global_nameserver] : []
    content {
      address = nameservers.value
    }
  }
}
