#!/usr/bin/env bash
#
# setup_subnet_router.sh
#
# Configures a Raspberry Pi as the Tailscale subnet router for the home LAN:
#   1. Enables IPv4/IPv6 forwarding (persisted in /etc/sysctl.d)
#   2. Installs or upgrades Tailscale from the official repository
#   3. Joins the tailnet as tag:subnet-router and advertises the LAN route
#
# Route approval is automatic via autoApprovers in the tailnet policy.
#
# Usage (on the Pi):
#   sudo bash setup_subnet_router.sh
#   sudo TS_AUTHKEY=tskey-auth-... LAN_CIDR=192.168.0.0/24 bash setup_subnet_router.sh
#
set -euo pipefail

readonly LAN_CIDR="${LAN_CIDR:-192.168.0.0/24}"
readonly TS_HOSTNAME="${TS_HOSTNAME:-rpi-subnet-router}"
readonly TS_TAGS="${TS_TAGS:-tag:subnet-router}"
readonly ACCEPT_DNS="${ACCEPT_DNS:-true}"
readonly SYSCTL_FILE="/etc/sysctl.d/99-tailscale.conf"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Run as root (sudo)."
}

enable_ip_forwarding() {
  log "Persisting IP forwarding in ${SYSCTL_FILE}"
  cat > "${SYSCTL_FILE}" <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
  sysctl -p "${SYSCTL_FILE}"
}

install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale present ($(tailscale version | head -n1)); upgrading"
    apt-get update -qq
    apt-get install -y --only-upgrade tailscale
  else
    log "Installing Tailscale from the official repository"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  systemctl enable --now tailscaled
}

tune_udp_gro() {
  # Best-effort throughput optimization for Linux subnet routers.
  local iface
  iface="$(ip -o route get 8.8.8.8 | awk '{for (i = 1; i <= NF; i++) if ($i == "dev") print $(i + 1)}')"
  if command -v ethtool >/dev/null 2>&1 && [[ -n "${iface}" ]]; then
    if ethtool -K "${iface}" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null; then
      log "Enabled UDP GRO forwarding on ${iface}"
    else
      log "UDP GRO forwarding not supported on ${iface}; skipping"
    fi
  fi
}

bring_up_tailscale() {
  local -a args=(
    "--hostname=${TS_HOSTNAME}"
    "--advertise-routes=${LAN_CIDR}"
    "--advertise-tags=${TS_TAGS}"
    "--accept-dns=${ACCEPT_DNS}"
    "--reset"
  )

  if tailscale status >/dev/null 2>&1; then
    log "Node already authenticated; re-applying settings"
  else
    if [[ -z "${TS_AUTHKEY:-}" ]]; then
      [[ -t 0 ]] || die "TS_AUTHKEY is not set and no TTY is available to prompt."
      read -rsp "Tailscale auth key: " TS_AUTHKEY
      echo
    fi
    args+=("--auth-key=${TS_AUTHKEY}")
  fi

  tailscale up "${args[@]}"
}

verify() {
  log "net.ipv4.ip_forward = $(sysctl -n net.ipv4.ip_forward)"
  log "Tailscale IPv4: $(tailscale ip -4)"
  tailscale status
  log "Advertising ${LAN_CIDR}. Approval is handled by the tailnet policy."
}

main() {
  require_root
  enable_ip_forwarding
  install_tailscale
  tune_udp_gro
  bring_up_tailscale
  verify
}

main "$@"
