# syntax=docker/dockerfile:1

# Jenkins LTS Custom Rootfs
# Base:    ubuntu-24-04-rootfs (systemd-enabled)
# Java:    OpenJDK 21
# Jenkins: LTS (latest stable)
# Nginx:   Reverse proxy pre-configured
# Cloudflared: For secure tunneling

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest

USER root

ARG USER
ARG JENKINS_PORT
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="Jenkins LTS Rootfs" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV DEBIAN_FRONTEND=noninteractive \
    JENKINS_HOME=/var/lib/jenkins \
    JENKINS_PORT=${JENKINS_PORT} \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}" \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Install Jenkins-specific packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Web server
        nginx \
        # Utilities for Jenkins
        fontconfig \
        gnupg \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy configuration files
COPY configs/nginx.conf /etc/nginx/sites-available/jenkins
COPY configs/jenkins.service /etc/systemd/system/jenkins.service
COPY configs/sudoers.d/jenkins-user /etc/sudoers.d/jenkins-user
COPY configs/profile.d/jenkins-env.sh /etc/profile.d/jenkins-env.sh
COPY configs/systemd/lab-init.service /etc/systemd/system/lab-init.service

# Copy and permission installation scripts
COPY scripts/ /opt/jenkins-scripts/
RUN chmod +x /opt/jenkins-scripts/*.sh

# Install Java and Jenkins
RUN /opt/jenkins-scripts/install-jenkins.sh ${JENKINS_PORT}

# Configure Nginx reverse proxy
RUN /opt/jenkins-scripts/configure-nginx.sh

# Enable services for systemd boot
RUN systemctl enable lab-init && \
    systemctl enable nginx && \
    systemctl enable jenkins

# Verify installations and configurations
RUN /opt/jenkins-scripts/healthcheck.sh ${USER}

# Install cloudflared for secure tunneling
RUN /opt/jenkins-scripts/install-cloudflared.sh

# Customize user's bashrc and add welcome message
USER $USER
ENV HOME=/home/$USER

COPY welcome $HOME/.welcome
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

USER root

EXPOSE 22 80 ${JENKINS_PORT}

CMD ["/lib/systemd/systemd"]
