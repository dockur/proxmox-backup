# syntax=docker/dockerfile:1

FROM debian:trixie

ARG TARGETARCH
ARG VERSION_ARG="0.0"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

SHELL ["/bin/bash", "-c"]

RUN <<EOF

# Break on errors
set -Eeuo pipefail
apt-get update

# Install prerequisites
apt-get update
apt-get full-upgrade -y
apt-get install -y --no-install-recommends \
  jq \
  tini \
  curl \
  nano \
  wget \
  htop \
  less \
  cpio \
  gosu \
  procps \
  locales \
  postfix \
  rsyslog \
  iptables \
  iproute2 \
  ifupdown2 \
  net-tools \
  nfs-common \
  cifs-utils \
  traceroute \
  iputils-ping \
  netcat-openbsd \
  ca-certificates \
  isc-dhcp-client
  
# Add Proxmox Backup Server repository
curl -sL https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
     -o /usr/share/keyrings/proxmox-archive-keyring.gpg

cat >/etc/apt/sources.list.d/pbs-no-subs.sources <<DEB
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
DEB

# Block unneeded packages in container
cat >/etc/apt/preferences.d/99-pdm-unneeded-packages <<BLK
Package: proxmox-default-kernel proxmox-kernel-* pve-firmware
Pin: release *
Pin-Priority: -1
BLK

# Prevent services from starting during install
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

# Stub commands unavailable / problematic in a Docker build
dpkg-divert --local --rename --add /usr/bin/unshare
printf '#!/bin/sh\nwhile [ $# -gt 0 ] && [ "$1" != "--" ]; do shift; done\n[ "$1" = "--" ] && \
shift\n[ $# -gt 0 ] && exec "$@"\nexit 0\n' > /usr/bin/unshare
chmod +x /usr/bin/unshare
dpkg-divert --local --rename --add /usr/sbin/update-initramfs
printf '#!/bin/sh\nexit 0\n' > /usr/sbin/update-initramfs
chmod +x /usr/sbin/update-initramfs
dpkg-divert --local --rename --add /usr/sbin/ifreload
printf '#!/bin/sh\n[ "$1" = "-V" ] && printf "%%s\n" "ifupdown2:3.3.0-1+pmx12"\nexit 0\n' > /usr/sbin/ifreload
chmod +x /usr/sbin/ifreload
printf '#!/bin/sh\nexit 0\n' > /usr/local/sbin/systemctl
chmod +x /usr/local/sbin/systemctl

# Install Proxmox Backup Server
apt-get update
apt-get install -y --no-install-recommends \
  proxmox-backup-docs \
  proxmox-backup-server

# Remove enterprise repo added by Proxmox packages — keep only no-subscription
rm -f /etc/apt/sources.list.d/pbs-enterprise.list \
      /etc/apt/sources.list.d/pbs-enterprise.sources \
      /etc/apt/sources.list.d/ceph.list \
      /etc/apt/sources.list.d/ceph.sources

# Prevent system updates
apt-mark hold proxmox-backup-server proxmox-backup-docs

# Cleanup
apt-get autoremove -y
apt-get clean

# Generate locales
locale-gen en_US.UTF-8

# Set username and password
echo "root:root" | chpasswd

# Redirect rsyslog
sed -i '/.*imklog.*/d' /etc/rsyslog.conf && \
    echo '*.* -/proc/1/fd/1' >> /etc/rsyslog.conf

# Store version number
echo "$VERSION_ARG" > /etc/version

# Cleanup files
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

EOF

WORKDIR /usr/local/bin
COPY --chmod=755 ./src /usr/local/bin/

ENV PASSWORD="root"

EXPOSE 8007

VOLUME /etc/proxmox-backup
VOLUME /var/lib/proxmox-backup

HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -kLfSs http://localhost:8007/ >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "-s", "/usr/local/bin/entrypoint.sh"]
