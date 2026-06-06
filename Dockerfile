# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 debian:trixie-slim AS base-amd64
FROM --platform=linux/arm64 debian:trixie-slim AS base-arm64

FROM base-${TARGETARCH} AS base

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
  cron \
  nano \
  wget \
  htop \
  iotop \
  runit \
  ssmtp \
  procps \
  iptables \
  iproute2 \
  ifupdown2 \
  net-tools \
  nfs-common \
  cifs-utils \
  iputils-ping \
  ca-certificates \
  isc-dhcp-client

wget https://github.com/ayufan/pve-backup-server-dockerfiles/releases/download/v${VERSION_ARG}/proxmox-backup-server-v{VERSION_ARG}-$(dpkg --print-architecture).tgz
tar zxf proxmox-backup-server-*.tgz
cd proxmox-backup-server-*/install
ls -lh

# Cleanup
apt-get autoremove -y
apt-get clean

# Mask unneeded services
ln -sf /dev/null /etc/systemd/system/ifupdown2-pre.service
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service

# Disable keyboard request target (for Docker TTY)
cat >/etc/systemd/system/kbrequest.target <<KBR
[Unit]
Description=Keyboard Request Target

[Target]
KBR

# Remove kernel modules and boot files — useless in a container (~960 MB)
rm -rf /usr/lib/modules /boot

# Remove hardware firmware blobs — no physical hardware in a container (~520 MB)
rm -rf /usr/lib/firmware

# Remove GPU/display/media libs — no display server, no GPU passthrough needed
rm -f \
  /usr/lib/*/libLLVM*.so* \
  /usr/lib/*/libgallium*.so* \
  /usr/lib/*/libvulkan_*.so* \
  /usr/lib/*/libz3.so* \
  /usr/lib/*/libx265.so* \
  /usr/lib/*/libcodec2.so* \
  /usr/lib/*/libavcodec.so* \
  /usr/lib/*/libavfilter.so* \
  /usr/lib/*/libSvtAv1Enc.so* \
  /usr/lib/*/libplacebo.so*

rm -rf \
  /usr/lib/*/dri \
  /usr/lib/*/gstreamer-1.0

# Remove share assets not needed at runtime
rm -rf \
  /usr/share/pocketsphinx \
  /usr/share/X11 \
  /usr/share/alsa \
  /usr/share/fonts \
  /usr/share/grub \
  /usr/share/groff \
  /usr/share/mime \
  /usr/share/man

# Set username and password
echo "root:root" | chpasswd

# Store version number
echo "$VERSION_ARG" > /etc/version

# Cleanup files
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

EOF

# Add default configs
ADD /dockerfiles/pbs/ /etc/proxmox-backup-default/
ADD /dockerfiles/runit/ /runit/

ENV PASSWORD="root"

EXPOSE 8007

VOLUME /etc/proxmox-backup
VOLUME /var/lib/proxmox-backup

STOPSIGNAL SIGRTMIN+3
HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -kLfSs http://localhost:8007 >/dev/null || exit 1

ENTRYPOINT ["/runit/entrypoint.sh"]
CMD ["runsvdir", "/runit"]
