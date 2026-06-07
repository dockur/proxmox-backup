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
apt-get --no-install-recommends -y install \
  curl \
  ca-certificates
apt-get clean
rm -rf /var/lib/apt/lists/*

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

# Install prerequisite packages
apt-get update
apt-get full-upgrade -y
apt-get install -y --no-install-recommends \
  jq \
  tini \
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
  isc-dhcp-client

# Install Proxmox Backup Server
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
