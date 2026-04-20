#!/usr/bin/env bash
#
# Install Docker CE + buildx + compose plugin in rootless mode.
#
# The inner dockerd runs as the non-root `vscode` user via
# dockerd-rootless.sh (from docker-ce-rootless-extras), so the outer
# devcontainer does NOT need --privileged.
#
# Runtime privileges required on the outer devcontainer:
#   cap_add:       NET_ADMIN (for agent-setup's ip route)
#   security_opt:  seccomp=unconfined, apparmor=unconfined, systempaths=unconfined
#   devices:       /dev/fuse (for fuse-overlayfs fallback)
#
# dockerd startup itself is handled by /usr/local/bin/docker-init.sh.

set -eux

USERNAME="${USERNAME:-vscode}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    iptables \
    pigz \
    xz-utils

# Add Docker's official GPG key and repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    docker-ce-rootless-extras \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    uidmap \
    slirp4netns \
    fuse-overlayfs \
    dbus-user-session

# Configure subuid/subgid for the non-root user so newuidmap/newgidmap
# can allocate a 65536-wide sub-uid range for rootless dockerd.
if ! grep -q "^${USERNAME}:" /etc/subuid; then
    echo "${USERNAME}:100000:65536" >> /etc/subuid
fi
if ! grep -q "^${USERNAME}:" /etc/subgid; then
    echo "${USERNAME}:100000:65536" >> /etc/subgid
fi

apt-get clean
rm -rf /var/lib/apt/lists/*
