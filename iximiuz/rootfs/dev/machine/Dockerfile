# syntax=docker/dockerfile:1.7
# =============================================================================
# Dev Machine Rootfs
# Built on top of ubuntu-24-04-rootfs base image
# Includes: Docker, kubectl, Helm, Terraform, AWS CLI, and all DevOps tools
# =============================================================================

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest

ARG USER
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="Dev Machine Rootfs" \
      org.opencontainers.image.description="DevOps dev machine with pre-installed tools" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

USER root

COPY scripts/install-tools.sh /tmp/scripts/install-tools.sh
RUN chmod +x /tmp/scripts/install-tools.sh && /tmp/scripts/install-tools.sh

# Set up all bash/zsh completions
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/setup-completions.sh

USER $USER
ENV HOME=/home/$USER

COPY welcome $HOME/.welcome

# Customize .bashrc with some useful functions, shortcuts, and alias definitions
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

EXPOSE 22
