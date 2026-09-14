# sekimore-relay: export the project token / endpoint written by sekimore-agent-setup.sh
# so that git-adjacent tools and `sekimore-relay agent ...` work from interactive shells.
# (The `sekimore` wrapper does the same for non-interactive processes.)
if [ -r /etc/sekimore-agent/env ]; then
  set -a
  source /etc/sekimore-agent/env
  set +a
fi
