# syntax=docker/dockerfile:1.7
#
# sgw-devcontainer-base
# Base image for Amakata personal-dev devcontainers that sit behind sekimore-gw.
#
# What's baked in:
#   - mcr.microsoft.com/devcontainers/base:bookworm  (provides vscode user uid=1000, git, sudo, etc.)
#   - common shell tooling (fzf, iproute2, jq, vim, rsync, ...)
#   - DB client dev headers (libpq-dev, default-libmysqlclient-dev)
#   - git-delta
#   - GitHub CLI (gh)
#   - zsh + oh-my-zsh + plugins
#   - anyenv + anyenv-update, with pyenv/nodenv/rbenv/phpenv plugins pre-installed
#     (no specific language versions — those are downstream's responsibility).
#     A copy of ~/.anyenv/envs is staged at ~/.anyenv/envs-default so
#     downstream can restore plugins after a volume mount shadows ~/.anyenv/envs.
#   - Claude Code CLI
#   - sekimore-gw agent-setup script (at /usr/local/bin/sekimore-agent-setup.sh)
#   - AWS CLI v2                (== devcontainers/features/aws-cli)
#   - Docker CE + buildx + compose plugin   (== devcontainers/features/docker-in-docker)
#
# What is NOT baked in (intentionally case-specific):
#   - sekimore-gw service itself (runs as a separate compose service)
#   - /workspace contents, .env, config.yml, zsh rc.d overlays
#   - anything pinned to a specific project layout
FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG USERNAME=vscode
ARG TARGETARCH

# ---------------------------------------------------------------------------
# Base apt packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      fzf \
      iptables \
      iproute2 \
      iputils-ping \
      dnsutils \
      jq \
      nano \
      vim \
      pv \
      wget \
      curl \
      ca-certificates \
      unzip \
      sudo \
      rsync \
      gnupg \
      # DB client dev headers
      libpq-dev default-libmysqlclient-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default vscode user has access to /usr/local/share
RUN chown -R ${USERNAME}:${USERNAME} /usr/local/share

# Persist zsh history via a well-known path (devcontainer mounts /commandhistory).
RUN mkdir -p /commandhistory \
    && touch /commandhistory/.zsh_history \
    && chown -R ${USERNAME} /commandhistory

# Orientation hint for tools that special-case devcontainers.
ENV DEVCONTAINER=true

RUN mkdir -p /workspace /home/${USERNAME}/.claude \
    && chown -R ${USERNAME}:${USERNAME} /workspace /home/${USERNAME}/.claude

WORKDIR /workspace

# ---------------------------------------------------------------------------
# git-delta
# ---------------------------------------------------------------------------
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# ---------------------------------------------------------------------------
# GitHub CLI (gh)
# ---------------------------------------------------------------------------
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# AWS CLI v2  (replaces ghcr.io/devcontainers/features/aws-cli:1)
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
        amd64) AWS_ARCH=x86_64 ;; \
        arm64) AWS_ARCH=aarch64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    cd /tmp; \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o awscliv2.zip; \
    unzip -q awscliv2.zip; \
    ./aws/install; \
    rm -rf awscliv2.zip aws

# ---------------------------------------------------------------------------
# Docker CE + buildx + compose  (replaces ghcr.io/devcontainers/features/docker-in-docker:2)
# ---------------------------------------------------------------------------
COPY scripts/install-docker.sh /tmp/install-docker.sh
RUN USERNAME=${USERNAME} bash /tmp/install-docker.sh && rm /tmp/install-docker.sh

# ---------------------------------------------------------------------------
# sekimore-gw agent-setup script
# Pulled at build time so the image is self-contained and the devcontainer
# can run `sudo /usr/local/bin/sekimore-agent-setup.sh` without network fetch.
# ---------------------------------------------------------------------------
ARG SEKIMORE_AGENT_REF=main
RUN wget -qO /usr/local/bin/sekimore-agent-setup.sh \
      "https://raw.githubusercontent.com/Amakata/sekimore-gw/${SEKIMORE_AGENT_REF}/agent-setup.sh" \
    && chmod +x /usr/local/bin/sekimore-agent-setup.sh

# ---------------------------------------------------------------------------
# zsh / oh-my-zsh / plugins  (as vscode user)
# ---------------------------------------------------------------------------
USER ${USERNAME}
ENV SHELL=/bin/zsh

# zsh plugins (oh-my-zsh is already installed in the devcontainers base image)
RUN git clone --depth 1 https://github.com/zsh-users/zsh-completions.git           ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions && \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git       ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git   ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting && \
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git      ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete

# ---------------------------------------------------------------------------
# anyenv + pyenv/nodenv/rbenv/phpenv plugins
#
# Only the plugins themselves are installed here — no specific language
# versions. Downstream images run e.g. `pyenv install 3.13.0` as needed.
#
# ~/.anyenv/envs is also copied to ~/.anyenv/envs-default so a devcontainer
# that mounts an empty volume at ~/.anyenv/envs can restore the plugin
# layout via:  rsync -a ~/.anyenv/envs-default/ ~/.anyenv/envs/
# ---------------------------------------------------------------------------
RUN git clone --depth 1 https://github.com/anyenv/anyenv ~/.anyenv
ENV PATH="/home/${USERNAME}/.anyenv/bin:${PATH}"

RUN mkdir -p ~/.anyenv/plugins && \
    git clone --depth 1 https://github.com/znz/anyenv-update.git ~/.anyenv/plugins/anyenv-update

SHELL ["/bin/zsh", "-lc"]
RUN anyenv install --force-init && \
    anyenv install pyenv && \
    anyenv install nodenv && \
    anyenv install rbenv && \
    anyenv install phpenv && \
    cp -a ~/.anyenv/envs ~/.anyenv/envs-default

# ---------------------------------------------------------------------------
# Claude Code CLI
# ---------------------------------------------------------------------------
RUN curl -fsSL https://claude.ai/install.sh | bash -s stable

# Drop back to default shell so downstream images aren't forced into zsh -lc.
SHELL ["/bin/sh", "-c"]

# ---------------------------------------------------------------------------
# Default zsh rc.d snippets
#
# Staged at /etc/skel/zsh-rc.d/. Downstream post-create scripts can copy
# these into ~/.config/zsh/rc.d/ (same pattern as envs-default):
#   rsync -a --ignore-existing /etc/skel/zsh-rc.d/ "$HOME/.config/zsh/rc.d/"
# Projects can override or add more snippets as needed.
# ---------------------------------------------------------------------------
USER root
COPY zsh-config/rc.d/ /etc/skel/zsh-rc.d/
RUN chown -R ${USERNAME}:${USERNAME} /etc/skel/zsh-rc.d/

USER ${USERNAME}
WORKDIR /workspace
