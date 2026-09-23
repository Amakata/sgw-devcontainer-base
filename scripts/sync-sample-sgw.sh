#!/usr/bin/env bash
# Bring examples/sgw-sample/.devcontainer/sgw/ in line with share/sgw/ and the sample's pinned versions:
# copy the distributed scripts and the English task file, and write MANIFEST the way upgrade.sh would.
#
# Run it after changing anything in share/sgw/, and when a release moves the sample's FROM tag or its
# gateway image tag. tests/test_sample_sgw.sh fails until the two agree.
#
# gateway.mise.toml is not touched: it is the gateway's, and comes from the sekimore-gw release the
# sample's compose file pins (share/gateway.mise.en.toml at that tag).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/share/sgw
SAMPLE=$ROOT/examples/sgw-sample
DST=$SAMPLE/.devcontainer/sgw
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

base=$(sed -n 's|^FROM ghcr.io/amakata/sgw-devcontainer-base:\([0-9.]*\).*|\1|p' "$SAMPLE/.devcontainer/Dockerfile")
gw=$(sed -n 's|^[[:space:]]*image:[[:space:]]*ghcr.io/amakata/sekimore-gw:\([0-9.]*\).*|\1|p' "$SAMPLE/.devcontainer/docker-compose.yml")
[ -n "$base" ] && [ -n "$gw" ] || { echo "sync-sample-sgw: the sample must pin both the base (Dockerfile) and the gateway (compose)" >&2; exit 1; }

mkdir -p "$DST"
for f in sgw.sh vscode.sh upgrade.sh post-start.sh; do cp "$SRC/$f" "$DST/$f"; chmod 755 "$DST/$f"; done
cp "$SRC/tasks.mise.en.toml" "$DST/tasks.mise.toml"
[ -f "$DST/gateway.mise.toml" ] || { echo "sync-sample-sgw: $DST/gateway.mise.toml is missing (take share/gateway.mise.en.toml from sekimore-gw v$gw)" >&2; exit 1; }
{
  # the header upgrade.sh writes, taken out of upgrade.sh so the two cannot differ
  sed -n '/^new_manifest() {/,/^}/p' "$SRC/upgrade.sh" | sed -n 's/^  echo "\(# .*\)"$/\1/p'
  echo "base $base"; echo "gateway $gw"; echo "lang en"
  for f in sgw.sh vscode.sh upgrade.sh post-start.sh tasks.mise.toml gateway.mise.toml; do echo "file $f $(sha "$DST/$f")"; done
} > "$DST/MANIFEST"
echo "sync-sample-sgw: examples/sgw-sample/.devcontainer/sgw/ at base $base, gateway $gw"
