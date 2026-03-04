# syntax=docker/dockerfile:1

# Nexus Repository Manager Custom Rootfs
# Base:    ubuntu-24-04-rootfs (systemd-enabled)
# Java:    OpenJDK 21
# Nexus:   3 (latest Community Edition)
# Nginx:   Reverse proxy pre-configured

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest

USER root

ARG USER
ARG NEXUS_PORT
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV DEBIAN_FRONTEND=noninteractive \
    NEXUS_HOME=/opt/nexus \
    NEXUS_DATA=/opt/sonatype-work \
    NEXUS_PORT=${NEXUS_PORT:-8081} \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}" \
    TZ=UTC

# Copy configuration files
COPY configs/nginx.conf /etc/nginx/sites-available/nexus
RUN sed -i "s/__NEXUS_PORT__/${NEXUS_PORT}/g" /etc/nginx/sites-available/nexus

COPY configs/nexus.service /etc/systemd/system/nexus.service
COPY configs/sudoers.d/nexus-user /etc/sudoers.d/nexus-user
COPY configs/systemd/lab-init.service /etc/systemd/system/lab-init.service

# Copy and permission scripts
COPY scripts/ /opt/nexus-scripts/
RUN chmod +x /opt/nexus-scripts/*.sh

# Install Java and Nexus
RUN /opt/nexus-scripts/install-nexus.sh ${NEXUS_PORT}

# Install and configure Nginx reverse proxy
RUN /opt/nexus-scripts/configure-nginx.sh

# Enable services for systemd boot
RUN systemctl enable lab-init && \
    systemctl enable nginx && \
    systemctl enable nexus

# Verify installations
RUN /opt/nexus-scripts/healthcheck.sh ${USER}

# Install cloudflared
RUN /opt/nexus-scripts/install-cloudflared.sh

# Customize user shell
USER $USER
ENV HOME=/home/$USER

COPY welcome $HOME/.welcome
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

USER root

EXPOSE 22 80 ${NEXUS_PORT}

CMD ["/lib/systemd/systemd"]
