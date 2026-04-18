# syntax=docker/dockerfile:1.7
#
# sgw-sample devcontainer image
#
# Builds on sgw-devcontainer-base. Only project-specific extras go here.
# Base tools (zsh, anyenv, pyenv/nodenv/phpenv/rbenv plugins, aws-cli,
# docker, sekimore agent-setup script, gh, ...) are already baked in.
FROM ghcr.io/amakata/sgw-devcontainer-base:latest

# ---------------------------------------------------------------------------
# PHP build dependencies
#
# phpenv (php-build) needs these -dev packages to compile PHP from source.
# The base image only includes DB client headers; the rest goes here so
# projects that don't use PHP aren't burdened with the extra layer size.
# ---------------------------------------------------------------------------
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential autoconf bison re2c pkg-config \
      libxml2-dev libsqlite3-dev libcurl4-openssl-dev libssl-dev \
      libreadline-dev libbz2-dev libzip-dev libonig-dev \
      # Image libs (GD)
      libpng-dev libjpeg-dev libfreetype6-dev libwebp-dev libavif-dev \
      # PHP extensions commonly required by CMSes (Adobe Commerce etc.)
      libtidy-dev libxslt1-dev libsodium-dev libgmp-dev libffi-dev \
      libicu-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER vscode
SHELL ["/bin/zsh", "-lc"]

# ---------------------------------------------------------------------------
# Install specific language versions via the anyenv plugins that are
# already pre-installed in the base image.
#
# Adjust versions to taste, or remove blocks you don't need.
# ---------------------------------------------------------------------------
ARG PYTHON_VERSION=3.13.0
ARG NODE_VERSION=22.11.0
ARG PHP_VERSION=8.3.12

RUN eval "$(anyenv init -)" && \
    pyenv install "${PYTHON_VERSION}" && \
    pyenv global "${PYTHON_VERSION}"

RUN eval "$(anyenv init -)" && \
    nodenv install "${NODE_VERSION}" && \
    nodenv global "${NODE_VERSION}"

RUN eval "$(anyenv init -)" && \
    phpenv install "${PHP_VERSION}" && \
    phpenv global "${PHP_VERSION}"

# ---------------------------------------------------------------------------
# Stage the populated ~/.anyenv/envs so the sample's anyenv-store volume
# can be bootstrapped on first start (see scripts/post-create.sh).
# ---------------------------------------------------------------------------
RUN cp -a ~/.anyenv/envs ~/.anyenv/envs-default

SHELL ["/bin/sh", "-c"]
WORKDIR /workspace
