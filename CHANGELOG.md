# sgw-devcontainer-base changelog

*[日本語版](CHANGELOG.ja.md)*

The devcontainer base image: the Dockerfile and the tools baked into it, the zsh
configuration and the scripts it ships, and the sample devcontainer under
`examples/`.

Entries are grouped **Security**, **Fix**, **Enhancement** — most urgent first —
and say what changed, with the pull request that changed it. The reasoning is in
the pull request.

Starts at 0.2.18. Releases before it are not written up here; the pull requests
and the tag on each are the record.

## 0.2.18 (2026-09-21)

### Fix

- the `sekimore` wrapper renews an expired project token again: it calls `POST /bootstrap` (`sekimore-relay agent bootstrap` never existed) and rewrites the env file in place, because its directory is root's (#38)

### Enhancement

- added this changelog, in English and Japanese, in the shape the gateway and the relay already use (#26)
