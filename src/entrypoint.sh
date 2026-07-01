#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${DEBUG:="N"}"             # Enable shell debugging with DEBUG=Y
: "${PASSWORD:="root"}"       # Default password
: "${POSTFIX:="Y"}"           # Start Postfix for outgoing system/report mails
: "${RELAY_HOST:="ext.home.local"}"

# Helper functions
info () { printf "%b%s%b" "\E[1;34m❯ \E[1;36m" "${1:-}" "\E[0m\n"; }
error () { printf "%b%s%b" "\E[1;31m❯ " "ERROR: ${1:-}" "\E[0m\n" >&2; }
warn () { printf "%b%s%b" "\E[1;31m❯ " "Warning: ${1:-}" "\E[0m\n" >&2; }

is_enabled() {
  case "${1:-}" in
    Y|y|YES|yes|TRUE|true|1|ON|on) return 0 ;;
    *) return 1 ;;
  esac
}

if is_enabled "$DEBUG"; then
  set -x
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Required command not found: $1"
    exit 21
  }
}

require_exec() {
  [ -x "$1" ] || {
    error "Required executable not found: $1"
    exit 22
  }
}

process_alive() {
  local pid="${1:-}"

  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

wait_process_alive() {
  local pid="${1:-}"
  local name="${2:-process}"
  local seconds="${3:-1}"

  sleep "$seconds"

  if ! process_alive "$pid"; then
    warn "$name exited shortly after startup."
    return 1
  fi

  return 0
}

read_pidfile() {
  local file

  for file; do
    if [ -f "$file" ]; then
      read -r REPLY < "$file"
      [ -n "${REPLY:-}" ] && return 0
    fi
  done

  REPLY=""
  return 1
}

# Check environment
[ "$(id -u)" -ne "0" ] && error "Script must be executed with root privileges." && exit 11
[ ! -f "/usr/local/bin/entrypoint.sh" ] && error "Script must be run inside the container!" && exit 12

# Check required binaries early.
require_cmd chpasswd
require_cmd gosu
require_cmd supercronic
require_cmd rsyslogd
require_cmd grep
require_cmd awk
require_cmd dpkg

if is_enabled "$POSTFIX"; then
  if [ ! -x /etc/init.d/postfix ]; then
    warn "POSTFIX=Y but /etc/init.d/postfix is missing or not executable."
  fi
fi

# Display version number
info "Starting Proxmox Backup Server for Docker v$(</etc/version)..."
info "For support visit https://github.com/dockur/proxmox-backup"
echo ""

# Update password for root
printf 'root:%s\n' "$PASSWORD" | chpasswd

# PBS expects /run to be tmpfs.
if ! grep -qE ' /run tmpfs ' /proc/mounts; then
  error "Please start the container with the \"--tempfs /run\" flag!"

  if ! is_enabled "$DEBUG"; then
    exit 14
  fi
fi

# If missing timezone and localtime set them.
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

# Ensure directory permissions.
user="backup"

if ! id "$user" >/dev/null 2>&1; then
  error "Required user does not exist: $user"
  exit 23
fi

# Give backup a shell for tools that expect it.
usermod -s /bin/bash "$user" >/dev/null || :

# Let root access backup-owned files through supplementary group membership.
# Do not change root's primary group.
usermod -a -G "$user" root >/dev/null || :
usermod -aG sudo "$user" >/dev/null || :

dir="/etc/proxmox-backup"
mkdir -p "$dir"
chmod 0700 "$dir" || :
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

# Detect PBS libexec directory.
multiarch=""

if command -v dpkg-architecture >/dev/null 2>&1; then
  multiarch="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || true)"
fi

if [ -n "$multiarch" ] && [ -d "/usr/lib/$multiarch/proxmox-backup" ]; then
  dir="/usr/lib/$multiarch/proxmox-backup"
else
  arch="$(dpkg --print-architecture)"

  case "$arch" in
    amd64)
      dir="/usr/lib/x86_64-linux-gnu/proxmox-backup"
      ;;
    arm64)
      dir="/usr/lib/aarch64-linux-gnu/proxmox-backup"
      ;;
    *)
      error "Unsupported architecture: $arch"
      exit 24
      ;;
  esac
fi

require_exec "$dir/proxmox-backup-api"
require_exec "$dir/proxmox-backup-proxy"

if [ ! -x "$dir/proxmox-daily-update" ]; then
  warn "Daily update helper not found or not executable: $dir/proxmox-daily-update"
fi

# Remove stale PID/socket files.
rm -f \
  /run/proxmox-backup/api.pid \
  /run/proxmox-backup/proxy.pid \
  /run/proxmox-backup/proxmox-backup-api.pid \
  /run/proxmox-backup/proxmox-backup-proxy.pid \
  /run/proxmox-backup/api.sock \
  /var/spool/postfix/pid/master.pid \
  /proxmox.end

# Start rsyslog early because PBS tools may expect /dev/log.
echo "Starting rsyslog..."

cat >/etc/rsyslog.conf <<'EOF'
module(load="imuxsock")
input(type="imuxsock" Socket="/dev/log")
template(name="DockerFormat" type="string" string="%programname%:%msg%\n")

if $msg contains '#000' then stop
if $msg contains 'IORITY' then stop
if $msg contains 'F_LOG_TARGET' then stop
if $msg contains 'SYSLOG_IDENTIFIER' then stop

if $programname == 'runuser' then stop
if $programname == 'rsyslogd' and $msg contains '[origin software="rsyslogd"' then stop

*.* action(type="omfile" file="/var/log/system.log" template="DockerFormat")
EOF

rm -f /dev/log /var/log/system.log
touch /var/log/system.log
chmod 0644 /etc/rsyslog.conf /var/log/system.log

rsyslogd -n -iNONE -f /etc/rsyslog.conf &
RSYSLOG_PID="$!"

while [ ! -S /dev/log ]; do
  sleep 0.2
done

mkdir -p /run/systemd/journal
ln -sf /dev/log /run/systemd/journal/syslog
ln -sf /dev/log /run/systemd/journal/socket

tail -F /var/log/system.log &
TAIL_PID="$!"

# Start Postfix.
#
# PBS can run without Postfix, but reports/notifications need local mail delivery.
POSTFIX_PID=""

if is_enabled "$POSTFIX"; then
  echo "Starting Postfix..."

  if [ -f /etc/postfix/main.cf ]; then
    if grep -q 'RELAY_HOST' /etc/postfix/main.cf; then
      sed -i "s|RELAY_HOST|$RELAY_HOST|g" /etc/postfix/main.cf
    fi
  fi

  if [ -x /etc/init.d/postfix ]; then
    /etc/init.d/postfix start || warn "Could not start Postfix."

    if read_pidfile /var/spool/postfix/pid/master.pid; then
      POSTFIX_PID="$REPLY"
    else
      warn "Postfix started but master.pid was not found."
    fi
  else
    warn "Postfix init script not found."
  fi
fi

# Start supercronic.
echo "Starting supercronic..."

cat >/docker.cron <<EOF
30 2 * * * $dir/proxmox-daily-update 2>&1 | tee -a /tmp/daily.log
EOF

supercronic -quiet -no-reap /docker.cron &
CRON_PID="$!"
wait_process_alive "$CRON_PID" "supercronic" 1 || :

# Trap helper.
_trap() {
  local func="$1"; shift
  local sig
  TRAP_PID="$BASHPID"

  for sig; do
    trap "$func $sig" "$sig"
  done
}

cleanup() {
  [ -f /proxmox.end ] && return 0
  [[ "${BASHPID:-}" != "${TRAP_PID:-}" ]] && return 0

  touch /proxmox.end
  echo "Shutting down PBS services..."

  pids=(
    "${PBS_PID:-}"
    "${API_PID:-}"
    "${CRON_PID:-}"
    "${POSTFIX_PID:-}"
    "${RSYSLOG_PID:-}"
    "${TAIL_PID:-}"
  )

  # Send SIGTERM.
  for pid in "${pids[@]}"; do
    [[ -z "${pid:-}" ]] && continue
    kill -0 "$pid" 2>/dev/null || continue
    kill -TERM "$pid" 2>/dev/null || :
  done

  if is_enabled "$POSTFIX" && [ -x /etc/init.d/postfix ]; then
    /etc/init.d/postfix stop 2>/dev/null || :
  fi

  # Wait for processes.
  for pid in "${pids[@]}"; do
    [[ -z "${pid:-}" ]] && continue
    kill -0 "$pid" 2>/dev/null || continue
    wait "$pid" 2>/dev/null || :
  done

  echo ""
  echo "Shutdown completed successfully."
  exit 0
}

# Init trap.
rm -f /proxmox.end
_trap cleanup SIGTERM SIGINT

# Start PBS services.
echo "Starting Proxmox Backup API..."

api_pid_file="/run/proxmox-backup/api.pid"
rm -f "$api_pid_file"

"$dir/proxmox-backup-api" &
API_PID="$!"

wait_process_alive "$API_PID" "proxmox-backup-api" 1 || cleanup

# Wait for the API process to be ready.
for i in $(seq 1 30); do
  [ -s "$api_pid_file" ] && break

  if ! process_alive "$API_PID"; then
    warn "Proxmox Backup API exited before writing pid file."
    cleanup
  fi

  info "Waiting for Backup API process ($i/30)..."
  sleep 1
done

if [ ! -s "$api_pid_file" ]; then
  warn "Backup API pid file not found after 30s, starting proxy anyway."
fi

echo "Starting Proxmox Backup Proxy as $user on port ${PORT:-8007}..."

gosu "$user" "$dir/proxmox-backup-proxy" "$@" &
PBS_PID="$!"

wait_process_alive "$PBS_PID" "proxmox-backup-proxy" 1 || cleanup

# Final readiness check.
echo "Checking PBS readiness..."

if command -v ss >/dev/null 2>&1; then
  for _ in $(seq 1 60); do
    if ss -ltn | grep -q ":${PORT:-8007} "; then
      break
    fi
    sleep 1
  done

  if ! ss -ltn | grep -q ":${PORT:-8007} "; then
    warn "PBS web interface does not appear to be listening on port ${PORT:-8007}."
  fi
else
  warn "Cannot run readiness port check because 'ss' is not installed."
fi

echo ""
info "------------------------------------------------------------------------------"
info ""
info ". Welcome to the Proxmox Backup Server v$(</etc/version). Connect your web browser to:"
info ""
info ".   https://127.0.0.1:${PORT:-8007}"
info ""
info "------------------------------------------------------------------------------"
info ""
echo ""

# Wait for required processes.
while true; do
  sleep 5

  process_alive "$API_PID" || break
  process_alive "$PBS_PID" || break

  if [ -n "${CRON_PID:-}" ] && ! process_alive "$CRON_PID"; then
    warn "supercronic exited. Daily update job will no longer run."
    CRON_PID=""
  fi

  if [ -n "${POSTFIX_PID:-}" ] && ! process_alive "$POSTFIX_PID"; then
    warn "Postfix exited. Notifications/reports may not work."
    POSTFIX_PID=""
  fi
done

info "A required PBS process exited unexpectedly. Shutting down..."
cleanup
