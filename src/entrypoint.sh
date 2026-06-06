#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${PASSWORD:="root"}"   # Default password

# Helper functions

info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

# Check environment
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 11

# Display version number
info "Starting Proxmox Backup Server for Docker v$(</etc/version)..."
info "For support visit https://github.com/dockur/proxmox-backup"
echo ""

# Update password for root
printf 'root:%s\n' "$PASSWORD" | chpasswd

# Create journald directory
mkdir -p /run/systemd/journal

# Provide the journald socket path expected by libsystemd callers
if [ ! -e /run/systemd/journal/socket ]; then
  ln -s /dev/log /run/systemd/journal/socket
fi

exec "$@"
