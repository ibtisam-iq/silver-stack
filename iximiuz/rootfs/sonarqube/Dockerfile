# syntax=docker/dockerfile:1

# SonarQube Community Edition Custom Rootfs
# Base:       ubuntu-24-04-rootfs (systemd-enabled)
# Java:       OpenJDK 21
# PostgreSQL: 18
# SonarQube:  26.2 Community Edition (LTA)
# Nginx:      Reverse proxy pre-configured

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest

USER root

ARG USER
ARG SONARQUBE_PORT
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV DEBIAN_FRONTEND=noninteractive \
    SONARQUBE_HOME=/opt/sonarqube \
    SONARQUBE_PORT=${SONARQUBE_PORT:-9000} \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}" \
    TZ=UTC

# Copy and permission installation scripts
COPY scripts/ /opt/sonarqube-scripts/
RUN chmod +x /opt/sonarqube-scripts/*.sh

# Copy configuration files
COPY configs/sonarqube.service /etc/systemd/system/sonarqube.service
COPY configs/sudoers.d/sonarqube-user /etc/sudoers.d/sonarqube-user
COPY configs/systemd/lab-init.service /etc/systemd/system/lab-init.service

# Install PostgreSQL and configure
RUN /opt/sonarqube-scripts/install-postgresql.sh

# Install SonarQube and configure
RUN /opt/sonarqube-scripts/install-sonarqube.sh ${SONARQUBE_PORT}

# Copy sonar.properties and substitute port placeholder
COPY configs/sonar.properties /opt/sonarqube/conf/sonar.properties
RUN sed -i "s/__SONARQUBE_PORT__/${SONARQUBE_PORT}/g" /opt/sonarqube/conf/sonar.properties && \
    chown sonar:sonar /opt/sonarqube/conf/sonar.properties

# Install and configure Nginx reverse proxy
RUN /opt/sonarqube-scripts/configure-nginx.sh

# Copy nginx.conf and substitute port placeholder
COPY configs/nginx.conf /etc/nginx/sites-available/sonarqube
RUN sed -i "s/__SONARQUBE_PORT__/${SONARQUBE_PORT}/g" /etc/nginx/sites-available/sonarqube

# Enable services for systemd boot
RUN systemctl enable lab-init && \
    systemctl enable postgresql && \
    systemctl enable nginx && \
    systemctl enable sonarqube

# Verify installations and configurations
RUN /opt/sonarqube-scripts/healthcheck.sh ${USER}

# Install cloudflared for secure tunneling
RUN /opt/sonarqube-scripts/install-cloudflared.sh

# Customize user's bashrc and add welcome message
USER $USER
ENV HOME=/home/$USER

COPY welcome $HOME/.welcome
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

USER root

EXPOSE 22 80 ${SONARQUBE_PORT}

CMD ["/lib/systemd/systemd"]
