# sgw-devcontainer-base changelog

*[日本語版](CHANGELOG.ja.md)*

The devcontainer base image: the Dockerfile and the tools baked into it, the zsh
configuration and the scripts it ships, and the sample devcontainer under
`examples/`.

Entries are grouped **Security**, **Fix**, **Enhancement** — most urgent first —
and say what changed, with the pull request that changed it. The reasoning is in
the pull request.

Every release names the sekimore-gw version it takes (`ARG SEKIMORE_GW_IMAGE` in
the Dockerfile), so the pairing between the two is this file.

Starts at 0.2.18. Releases before it are not written up here; the pull requests
and the tag on each are the record. The gateway each of them took is at the
bottom.

## 0.2.18 (2026-09-21)

### Fix

- the `sekimore` wrapper renews an expired project token again: it calls `POST /bootstrap` (`sekimore-relay agent bootstrap` never existed) and rewrites the env file in place, because its directory is root's (#38)

### Enhancement

- takes gateway 0.2.29 (#40)
- README.md is English and README.ja.md Japanese, as the other repositories are; the sample `config.yml` is commented in English and lists every key the gateway reads, all 28 permissions among them (#39)
- added this changelog, in English and Japanese, in the shape the gateway and the relay already use (#26)

## Before 0.2.18

Not written up: the pull request and the tag on each is the record. What is kept
here is the gateway each one took.

- 0.2.17 took gateway 0.2.15
- 0.2.16 took gateway 0.2.15
- 0.2.15 took gateway 0.2.14
- 0.2.14 took gateway 0.2.13
- 0.2.13 took gateway 0.2.13
- 0.2.12 took gateway 0.2.11
