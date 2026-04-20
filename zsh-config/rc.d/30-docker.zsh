# Rootless Docker socket
#
# dockerd-rootless.sh listens on $XDG_RUNTIME_DIR/docker.sock.
# Ensure XDG_RUNTIME_DIR is set even for non-login shells so the docker
# CLI can find the daemon.
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR}/docker.sock"
