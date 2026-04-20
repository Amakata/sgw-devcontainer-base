#!/usr/bin/env bash
#
# Rootless dockerd entrypoint helper, baked into the base image.
#
# Starts dockerd-rootless.sh in the background if it is not already
# running. Intended to be called from the consuming devcontainer.json's
# postStartCommand, as the non-root user (e.g. vscode).
#
# The resulting socket is $XDG_RUNTIME_DIR/docker.sock. DOCKER_HOST is
# set by zsh-config/rc.d/30-docker.zsh so interactive shells pick it up
# automatically.

set -e

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    sudo mkdir -p "$XDG_RUNTIME_DIR"
    sudo chown "$(id -u):$(id -g)" "$XDG_RUNTIME_DIR"
    sudo chmod 700 "$XDG_RUNTIME_DIR"
fi

SOCKET="$XDG_RUNTIME_DIR/docker.sock"
export DOCKER_HOST="unix://$SOCKET"

if [ -S "$SOCKET" ] && docker info >/dev/null 2>&1; then
    exit 0
fi

nohup dockerd-rootless.sh > /tmp/dockerd-rootless.log 2>&1 &

for _ in $(seq 1 30); do
    if [ -S "$SOCKET" ] && docker info >/dev/null 2>&1; then
        exit 0
    fi
    sleep 1
done

echo "rootless dockerd failed to start within 30s — see /tmp/dockerd-rootless.log" >&2
exit 1
