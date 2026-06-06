# syntax=docker/dockerfile:1

ARG VERSION_ARG="latest"
FROM ayufan/proxmox-backup-server:v${VERSION_ARG} AS base

ARG TARGETARCH
ARG VERSION_ARG="0.0"

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

SHELL ["/bin/bash", "-c"]

RUN <<EOF

# Break on errors
set -Eeuo pipefail

# Set username and password
echo "root:root" | chpasswd

# Store version number
echo "$VERSION_ARG" > /etc/version

# Cleanup files
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

EOF

COPY --chmod=755 ./src/entrypoint.sh /runit/

EXPOSE 8007
STOPSIGNAL SIGHUP

VOLUME /etc/proxmox-backup
VOLUME /var/log/proxmox-backup
VOLUME /var/lib/proxmox-backup

HEALTHCHECK --interval=60s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -kLfSs http://localhost:8007 >/dev/null || exit 1

ENTRYPOINT ["/runit/entrypoint.sh"]
CMD ["runsvdir", "/runit"]
