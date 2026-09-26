#!/usr/bin/env bash
#
# setup_pihole_ssh_node.sh
#
# Joins the Pi-hole Raspberry Pi to the tailnet with Tailscale SSH enabled:
#   1. Installs or upgrades Tailscale from the official repository
#   2. Joins as tag:dns with --ssh, and --accept-dns=false so Pi-hole never
#      resolves through itself via the tailnet (avoids a DNS loop)
#   3. Allows Pi-hole to answer queries arriving on the tailscale0 interface
#
# Usage (on the Pi):
#   sudo bash setup_pihole_ssh_node.sh
#   sudo TS_AUTHKEY=tskey-auth-... bash setup_pihole_ssh_node.sh
#
set -euo pipefail

readonly TS_HOSTNAME="${TS_HOSTNAME:-rpi-pihole}"
readonly TS_TAGS="${TS_TAGS:-tag:dns}"
readonly PIHOLE_LISTEN_ALL="${PIHOLE_LISTEN_ALL:-true}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Run as root (sudo)."
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

bring_up_tailscale() {
  local -a args=(
    "--hostname=${TS_HOSTNAME}"
    "--advertise-tags=${TS_TAGS}"
    "--ssh"
    "--accept-dns=false"
    "--accept-routes=false"
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

configure_pihole_listening() {
  if [[ "${PIHOLE_LISTEN_ALL}" != "true" ]]; then
    log "PIHOLE_LISTEN_ALL=false; leaving Pi-hole listening mode unchanged"
    return
  fi
  command -v pihole >/dev/null 2>&1 || die "Pi-hole is not installed on this host."

  # Pi-hole's default only answers queries from directly connected subnets,
  # so queries from tailnet clients (100.64.0.0/10) are dropped until this is set.
  # Safe here: port 53 is not forwarded on the home router, and tailnet access
  # to port 53 is restricted by the tailnet policy.
  if [[ -f /etc/pihole/pihole.toml ]]; then
    pihole-FTL --config dns.listeningMode ALL
    log "Pi-hole v6: dns.listeningMode set to ALL"
  else
    local vars=/etc/pihole/setupVars.conf
    if grep -q '^DNSMASQ_LISTENING=' "${vars}"; then
      sed -i 's/^DNSMASQ_LISTENING=.*/DNSMASQ_LISTENING=all/' "${vars}"
    else
      echo 'DNSMASQ_LISTENING=all' >> "${vars}"
    fi
    pihole restartdns
    log "Pi-hole v5: DNSMASQ_LISTENING set to all"
  fi
}

verify() {
  local ts_ip
  ts_ip="$(tailscale ip -4)"
  tailscale status
  log "Tailscale SSH enabled. Connect with: tailscale ssh <user>@${TS_HOSTNAME}"
  log "Pi-hole tailnet address: ${ts_ip} (candidate global nameserver)"
}

main() {
  require_root
  install_tailscale
  bring_up_tailscale
  configure_pihole_listening
  verify
}

main "$@"
