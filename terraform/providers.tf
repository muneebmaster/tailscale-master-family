terraform {
  required_version = ">= 1.6.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}

# Credentials are read from the environment, never from files in this repo:
#   TAILSCALE_API_KEY
#   or TAILSCALE_OAUTH_CLIENT_ID + TAILSCALE_OAUTH_CLIENT_SECRET
provider "tailscale" {
  tailnet = var.tailnet
}
