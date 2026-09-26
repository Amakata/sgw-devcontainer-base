# sgw-devcontainer-base — moved

This repository is archived. From gateway 0.2.46 the dev-container base image is built from
[`base/` of sekimore-gw](https://github.com/Amakata/sekimore-gw/tree/main/base) and released from
the same tag, under the gateway's version number. The image name is unchanged:
`ghcr.io/amakata/sgw-devcontainer-base`.

The `v0.2.46` tag here exists for one reason: an `upgrade.sh` from 0.2.43 or earlier reads the
distributed files from this repository, and this tag holds the 0.2.46 files so that
`mise run upgrade:apply` crosses over once. From then on the files come from sekimore-gw.

History up to 0.2.43 is here. Issues and pull requests go to
[sekimore-gw](https://github.com/Amakata/sekimore-gw).
