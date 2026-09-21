#!/usr/bin/env bash
# sgw.sh — operate this devcontainer's compose stack (started by the Dev Containers extension) from the Mac.
# Called from the mise.toml tasks. To use it directly:
#
#   sgw.sh gw   [cmd...]   run cmd in the sekimore-gw container (default: sekimore-relay check)
#   sgw.sh dev  [cmd...]   run cmd in the dev container (as the vscode user. default: zsh)
#   sgw.sh id   <service>  print the container ID
#   sgw.sh project         print the compose project name (Dev Containers: "<folder name>_devcontainer")
#   sgw.sh ps              list the stack's containers
#   sgw.sh recreate        pull the latest image and recreate the gateway (docker restart keeps the old one)
#
# How it finds them: the compose labels (service name + the project's working_dir = this .devcontainer).
# The project name depends on the folder name, so look it up by label rather than by name.
set -euo pipefail

ROOT=${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
COMPOSE_DIR=${SGW_COMPOSE_DIR:-$ROOT/.devcontainer}

if [ "${DEVCONTAINER:-}" = "true" ] && [ -z "${SGW_FORCE:-}" ]; then
  echo "sgw: this is the inside of the dev container; run it on the host (Mac) where Docker Desktop runs the stack." >&2
  exit 2
fi

by_label() { docker ps -q --filter "label=com.docker.compose.project.working_dir=$COMPOSE_DIR" "$@"; }

find_container() {
  local svc=$1 ids n
  ids=$(by_label --filter "label=com.docker.compose.service=$svc")
  if [ -z "$ids" ]; then
    # fallback where the working_dir label does not match (path normalization differences, etc.):
    # take it when the service name alone is unique
    ids=$(docker ps -q --filter "label=com.docker.compose.service=$svc")
  fi
  n=$(printf '%s\n' "$ids" | grep -c . || true)
  if [ "$n" -eq 0 ]; then
    echo "sgw: no running container for service '$svc' (is the devcontainer open? working_dir=$COMPOSE_DIR)" >&2
    docker ps -a --format '  {{.Names}}  {{.Status}}  ({{.Image}})' --filter "label=com.docker.compose.service=$svc" >&2 || true
    exit 1
  fi
  if [ "$n" -gt 1 ]; then
    echo "sgw: several '$svc' containers are running; stop the others or set MISE_PROJECT_ROOT / SGW_COMPOSE_DIR:" >&2
    docker ps --format '  {{.Names}}  {{.Label "com.docker.compose.project.working_dir"}}' --filter "label=com.docker.compose.service=$svc" >&2
    exit 1
  fi
  printf '%s' "$ids"
}

# Build compose's -f / --env-file arguments into the array FARGS. $1 = the project working_dir,
# $2 = the config_files label ("," separated), $3 = env file.
# A path can hold spaces (the Dev Containers generated file lives under
# "~/Library/Application Support/…"), so keep them in an array rather than concatenating a string.
# The config_files label is used when it is there, but a container recreated in the past without the
# overlay has no overlay left in its label either.
# On a relay setup (docker-compose.relay.yml exists) always include that file. Files that do not exist,
# and duplicates, are skipped.
compose_args() {
  local wd=$1 cfgs=$2 envfile=$3 c
  FARGS=()
  add_f() {
    local f=$1 x
    [ -f "$f" ] || return 0
    for x in "${FARGS[@]}"; do [ "$x" = "$f" ] && return 0; done
    FARGS+=(-f "$f")
  }
  if [ -n "$cfgs" ]; then
    local OLDIFS=$IFS; IFS=","
    for c in $cfgs; do
      case "$c" in /*) add_f "$c" ;; *) add_f "$wd/$c" ;; esac
    done
    IFS=$OLDIFS
  fi
  [ ${#FARGS[@]} -eq 0 ] && add_f "$wd/docker-compose.yml"
  add_f "$wd/docker-compose.relay.yml"
  [ -n "$envfile" ] && [ -f "$envfile" ] && FARGS+=(--env-file "$envfile")
  return 0
}


tty_flag() { if [ -t 0 ] && [ -t 1 ]; then echo "-it"; else echo "-i"; fi; }

case "${1:-}" in
  gw)
    shift; cid=$(find_container sekimore-gw)
    if [ $# -eq 0 ]; then set -- sekimore-relay check; fi
    exec docker exec "$(tty_flag)" "$cid" "$@" ;;
  # Always -it, for a command that reads a passphrase. tty_flag asks for stdout as well, and a
  # task runner that prefixes output makes stdout a pipe — so the detection says "no terminal"
  # while the person is sitting at one. What matters here is stdin, and asking for a terminal we
  # do not need costs nothing: docker only refuses -t when stdin itself is not one.
  gw-tty)
    shift; cid=$(find_container sekimore-gw)
    [ -t 0 ] || { echo "sgw.sh: $* needs a terminal on stdin (do not pipe it)" >&2; exit 2; }
    exec docker exec -it "$cid" "$@" ;;
  dev)
    shift; cid=$(find_container dev)
    if [ $# -eq 0 ]; then set -- zsh; fi
    exec docker exec "$(tty_flag)" -u vscode "$cid" "$@" ;;
  id)
    find_container "${2:?usage: sgw.sh id <service>}"; echo ;;
  recreate)
    # Recreate the gateway on the latest image. docker restart resumes with the existing image, so it
    # does not swap.
    # Use it after bumping the image tag in compose (the Web UI's Relay tab is stale, etc.).
    # Dev Containers layers several compose files (docker-compose.yml + docker-compose.relay.yml + the
    # generated one), so pass every one of them with -f, taken from the container's config_files label.
    # Missing even one drops the relay overlay (the agent socket mount, etc.) and breaks the gateway.
    cid=$(find_container sekimore-gw)
    running=$(docker inspect -f "{{.Config.Image}}" "$cid")
    proj=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project\"}}" "$cid")
    wd=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project.working_dir\"}}" "$cid")
    cfgs=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project.config_files\"}}" "$cid")
    envfile=$(docker inspect -f "{{index .Config.Labels \"com.docker.compose.project.environment_file\"}}" "$cid")
    compose_args "$wd" "$cfgs" "$envfile"
    # What is pulled is the image compose declares (right after a tag bump it is newer than the running
    # container's image).
    # compose up does not re-pull a tag it already has, so an update to the same tag (latest, etc.) is
    # taken in here too.
    # Where compose config is unavailable, it falls back to the running container's image
    image=$(docker compose -p "$proj" --project-directory "$wd" "${FARGS[@]}" config --images sekimore-gw 2>/dev/null | head -1)
    image=${image:-$running}
    if [ "$image" != "$running" ]; then echo "gateway: $running → $image (project=$proj)"; else echo "gateway: $image (project=$proj)"; fi
    printf 'compose:'; printf ' %q' "${FARGS[@]}"; echo
    echo "before:  $(docker inspect -f "{{.Image}}" "$cid")"
    docker pull "$image"
    docker compose -p "$proj" --project-directory "$wd" "${FARGS[@]}" up -d --force-recreate sekimore-gw
    new=$(find_container sekimore-gw)
    echo "after:   $(docker inspect -f "{{.Image}}" "$new")"
    printf "waiting for the gateway"
    for _ in $(seq 1 30); do
      # the gateway has no curl, so hit it with python (always present)
      if docker exec "$new" python -c "import urllib.request,sys; urllib.request.urlopen(\"http://127.0.0.1:8080/api/config\",timeout=3)" 2>/dev/null; then echo " ok"; break; fi
      printf "."; sleep 1
    done
    echo "done. reload the Web UI Relay tab (or run: mise run gw:check)" ;;
  project)
    cid=$(find_container sekimore-gw)
    docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$cid" ;;
  ps)
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' --filter "label=com.docker.compose.project.working_dir=$COMPOSE_DIR" ;;
  *)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
