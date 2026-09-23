#!/bin/sh
# post-start.sh — what devcontainer.json's postStartCommand runs, inside the dev container:
#
#   1. sekimore-agent-setup.sh as root, with every SEKIMORE_* variable this container has
#   2. docker-init.sh, which starts the Docker daemon inside dev
#   3. the project's own .devcontainer/scripts/post-create.sh, when there is one
#
#   "postStartCommand": "sh /workspace/.devcontainer/sgw/post-start.sh"
#
# Why every SEKIMORE_* variable rather than a list: sudo resets the environment, so a variable
# from .env reaches agent-setup only if --preserve-env= names it, and one it does not name is set
# and then silently ignored. That list used to sit in devcontainer.json, the project's own file,
# and fell behind each time agent-setup gained an input (SEKIMORE_GUIDE_LANG). The names are taken
# from the environment at the moment this runs, so there is nothing to keep in step. It hands root
# nothing new: these are the container's own environment, which the vscode user already has.
#
# Anything else a project wants at start goes in .devcontainer/scripts/post-create.sh, which is
# the project's.
#
# Distributed by sgw-devcontainer-base: `mise run upgrade:apply` replaces this file, and stops
# rather than overwrite it once it has been edited.
set -e

here=$(cd "$(dirname "$0")" && pwd)
# The three steps' commands, overridable only so tests can stand in for them
agent_setup=${SGW_AGENT_SETUP:-/usr/local/bin/sekimore-agent-setup.sh}
docker_init=${SGW_DOCKER_INIT:-/usr/local/bin/docker-init.sh}
post_create=${SGW_POST_CREATE:-$here/../scripts/post-create.sh}

# Names only, one per line, then joined with commas: SEKIMORE_ followed by the rest of a name
vars=$(env | sed -n 's/^\(SEKIMORE_[A-Za-z0-9_]*\)=.*/\1/p' | sort -u | paste -sd, -)
if [ -n "$vars" ]; then
  sudo --preserve-env="$vars" "$agent_setup"
else
  sudo "$agent_setup"
fi
"$docker_init"
if [ -f "$post_create" ]; then
  sh "$post_create"
fi
