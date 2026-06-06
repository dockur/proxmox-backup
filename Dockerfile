# syntax=docker/dockerfile:1

ARG VERSION_ARG="latest"
FROM ayufan/proxmox-backup-server:{VERSION_ARG} AS base

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
  iputils-ping \
  ca-certificates

# Cleanup
apt-get autoremove -y
apt-get clean

# Store version number
echo "$VERSION_ARG" > /etc/version

# Cleanup files
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

EOF

EXPOSE 8007

VOLUME /etc/proxmox-backup
VOLUME /var/lib/proxmox-backup

HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -kLfSs http://localhost:8007 >/dev/null || exit 1

ENTRYPOINT ["/runit/entrypoint.sh"]
CMD ["runsvdir", "/runit"]
