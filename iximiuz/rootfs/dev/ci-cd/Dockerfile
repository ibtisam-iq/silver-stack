# syntax=docker/dockerfile:1

# SilverStack CI/CD Dev Machine
# Base: ubuntu-24-04-rootfs (systemd-enabled)
# Purpose: Developer workstation for SilverStack CI/CD stack

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest

ARG USER
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

USER $USER
ENV HOME=/home/$USER

COPY welcome $HOME/.welcome
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

EXPOSE 22
