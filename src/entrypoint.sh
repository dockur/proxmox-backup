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
[ ! -f "/usr/local/bin/entrypoint.sh" ] && error "Script must be run inside the container!" && exit 12

# Display version number
info "Starting Proxmox Backup Server for Docker v$(</etc/version)..."
info "For support visit https://github.com/dockur/proxmox-backup"
echo ""

# Update password for root
printf 'root:%s\n' "$PASSWORD" | chpasswd

# If missing timezone and localtime set them
set_timezone() {
  local zone="$1"

  if [ ! -f "/usr/share/zoneinfo/$zone" ]; then
    echo "Invalid timezone: $zone" >&2
    exit 18
  fi

  ln -snf "/usr/share/zoneinfo/$zone" /etc/localtime
  echo "$zone" > /etc/timezone
}

check_localtime() {
  if [ ! -e /etc/localtime ] && [ ! -L /etc/localtime ]; then
    return 1
  fi

  local target
  target="$(readlink -f /etc/localtime 2>/dev/null || true)"

  if [ -z "$target" ] || [ ! -f "$target" ] || [ ! -s "$target" ]; then
    echo "Invalid TZ value." >&2
    exit 1
  fi

  return 0
}

if [ -n "${TZ:-}" ]; then
  set_timezone "$TZ"
elif ! check_localtime; then
  set_timezone "UTC"
fi

# Start rsyslog
echo "Starting rsyslog..."
rsyslogd
RSYSLOG_PID=$(cat /var/run/rsyslogd.pid 2>/dev/null || echo "")

echo "Starting Postfix..."
RELAY_HOST=${RELAY_HOST:-ext.home.local}
sed -i "s/RELAY_HOST/$RELAY_HOST/" /etc/postfix/main.cf

/etc/init.d/postfix start || ok=1
read -r POSTFIX_PID < /var/spool/postfix/pid/master.pid

# Ensure directory permissions
user="backup"
dir="/etc/proxmox-backup"

usermod -s /bin/bash "$user" >/dev/null || :
usermod -a -G "$user" root >/dev/null || :
usermod -g "$user" root >/dev/null || :
usermod -aG sudo "$user" >/dev/null || :
    
mkdir -p "$dir"
chmod 700 "$dir" || :
chown "$user:$user" "$dir" || :

dir="/var/lib/proxmox-backup"
mkdir -p "$dir"
chown "$user:$user" "$dir" || :

dir="/var/log/proxmox-backup"
mkdir -p "$dir"
chown "$user:$user" "$dir" || :

dir="/run/proxmox-backup"
mkdir -p "$dir"
chown "$user:$user" "$dir" || :

_trap() {
  local func="$1"; shift
  local sig
  TRAP_PID=$BASHPID

  for sig; do
    trap "$func $sig" "$sig"
  done
}

cleanup() {

  [ -f /proxmox.end ] && return 0
  [[ $BASHPID != "$TRAP_PID" ]] && return 0

  touch /proxmox.end
  echo "Shutting down PBS services..."
  
  pids=(
    "$PBS_PID"
    "$API_PID"
    "$POSTFIX_PID"
    "$RSYSLOG_PID"
  )

  # Send SIGTERM 
  for pid in "${pids[@]}"; do
    [[ -z "${pid:-}" ]] && continue
    kill -0 "$pid" 2>/dev/null || continue
    kill -TERM "$pid" 2>/dev/null || :
  done

  # Wait for processes
  for pid in "${PIDS[@]}"; do
    [[ -z "${pid:-}" ]] && continue
    kill -0 "$pid" 2>/dev/null || continue
    wait "$pid" 2>/dev/null || :
  done

  echo ""
  echo "Shutdown completed successfully."
  exit 0
}

# Init trap
rm -f /proxmox.end
_trap cleanup SIGTERM SIGINT

# Start PBS Services
echo "Starting Proxmox Backup API..."

file="/run/proxmox-backup/api.pid"
dir="/usr/lib/x86_64-linux-gnu/proxmox-backup"
rm -f "$file"

"$dir/proxmox-backup-api" &
API_PID=$!

# Wait for the API process to be ready
for i in $(seq 0 30); do
  [ -s "$file" ] && break
  (( i > 0 )) && info "Waiting for Backup API process ($i/30)..."
  sleep 1
done

if [ ! -s "$file" ]; then
  warn "Backup API server not started after 30s, continuing anyway."
fi

echo "Starting PBS..."
gosu backup "$dir/proxmox-backup-proxy" "$@" &
PBS_PID=$!

echo ""
info "------------------------------------------------------------------------------"
info ""
info ". Welcome to the Proxmox Backup Server v$(</etc/version). Connect your web browser to:"
info ""
info ".   https://127.0.0.1:${PORT:-8007}"
info ""
info "------------------------------------------------------------------------------"
info ""

# Wait for processes
wait -n "${API_PID:-}" "${PBS_PID:-}" 2>/dev/null || :

info "A PBS process exited unexpectedly. Shutting down..."
cleanup
