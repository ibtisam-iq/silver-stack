# syntax=docker/dockerfile:1
# Guacamole Browser-based Desktop Rootfs
# Base:       ubuntu-24-04-rootfs (systemd-enabled)
# Desktop:    XFCE4 + XRDP + PipeWire audio
# Browser:    Mozilla Firefox (official apt repo)
# Gateway:    Apache Guacamole 1.6.0 (native, no Docker)
# Database:   MariaDB
# Web:        Tomcat 10 + Nginx reverse proxy
# Tunnel:     cloudflared (Cloudflare Tunnel)

FROM ghcr.io/ibtisam-iq/ubuntu-24-04-rootfs:latest
USER root

# ── Build arguments ───────────────────────────────────────────────────────────
ARG USER
ARG GUAC_PORT
ARG GUAC_VERSION
ARG MYSQL_CONNECTOR_VERSION
ARG RDP_USER
ARG RDP_PORT
ARG DB_NAME
ARG DB_USER
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# ── Environment variables (runtime-visible) ───────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive \
    GUAC_VERSION=${GUAC_VERSION:-1.6.0} \
    MYSQL_CONNECTOR_VERSION=${MYSQL_CONNECTOR_VERSION:-9.2.0} \
    GUAC_PORT=${GUAC_PORT:-8080} \
    RDP_USER=${RDP_USER:-musk} \
    RDP_PORT=${RDP_PORT:-3389} \
    DB_NAME=${DB_NAME:-guacamole_db} \
    DB_USER=${DB_USER:-guacamole_user} \
    GUACAMOLE_HOME=/etc/guacamole \
    TZ=UTC

# ── Copy scripts and configs ──────────────────────────────────────────────────
COPY scripts/ /opt/guacamole-scripts/
RUN chmod +x /opt/guacamole-scripts/*.sh

COPY configs/systemd/lab-init.service     /etc/systemd/system/lab-init.service
COPY configs/systemd/guacamole.service    /etc/systemd/system/guacamole.service
COPY configs/sudoers.d/guacamole-user     /etc/sudoers.d/guacamole-user

COPY configs/nginx/guacamole.conf        /etc/nginx/sites-available/guacamole

# ── Phase 1: Install desktop (XFCE4 + XRDP + Firefox + PipeWire) ─────────────
RUN /opt/guacamole-scripts/install-desktop.sh

COPY configs/xrdp/startwm.sh             /etc/xrdp/startwm.sh

# ── Phase 2: Configure XRDP ───────────────────────────────────────────────────
RUN /opt/guacamole-scripts/configure-xrdp.sh "${RDP_USER}" "${RDP_PORT}"

# ── Phase 3: Install Guacamole native (guacd + WAR + MariaDB + JDBC) ─────────
RUN /opt/guacamole-scripts/install-guacamole.sh \
    "${GUAC_VERSION}" "${MYSQL_CONNECTOR_VERSION}"

# ── Phase 4: Configure Guacamole (guacamole.properties + Tomcat symlink) ─────
RUN /opt/guacamole-scripts/configure-guacamole.sh \
    "${DB_NAME}" "${DB_USER}" "${GUAC_PORT}"

# ── Phase 5: Configure Nginx reverse proxy ────────────────────────────────────
RUN sed -i "s/__GUAC_PORT__/${GUAC_PORT}/g" /etc/nginx/sites-available/guacamole && \
    /opt/guacamole-scripts/configure-nginx.sh

# ── Phase 6: Enable all systemd services ─────────────────────────────────────
RUN systemctl enable lab-init && \
    systemctl enable mariadb && \
    systemctl enable tomcat10 && \
    systemctl enable guacd && \
    systemctl enable xrdp && \
    systemctl enable xrdp-sesman && \
    systemctl enable nginx

# ── Phase 6b: Disable unnecessary desktop services ───────────────────────────
RUN systemctl disable lightdm cups cups-browsed avahi-daemon whoopsie 2>/dev/null || true

# ── Phase 6c: Docker/overlay2 compatibility overrides ────────────────────────
# guacd: bind 0.0.0.0 so Tomcat can reach it via IPv4 (127.0.0.1) in Docker.
#        On iximiuz block devices this is also safe — 0.0.0.0 accepts both.
# MariaDB: innodb_use_native_aio=0 + fsync for overlay2 I/O safety.
RUN mkdir -p /etc/systemd/system/guacd.service.d && \
    mkdir -p /etc/mysql/conf.d
COPY configs/systemd/guacd.override.conf \
     /etc/systemd/system/guacd.service.d/override.conf
COPY configs/mariadb/docker-compat.cnf \
     /etc/mysql/conf.d/docker-compat.cnf

# ── Phase 7: Install cloudflared ─────────────────────────────────────────────
RUN /opt/guacamole-scripts/install-cloudflared.sh

# ── Phase 8: Build-time health check ─────────────────────────────────────────
RUN /opt/guacamole-scripts/healthcheck.sh "${USER}" "${GUAC_VERSION}"

# ── Fix ownership of $HOME written during build ───────────────────────────────
RUN chown -R ${USER}:${USER} /home/${USER}

# ── Customize shell for interactive user ─────────────────────────────────────
USER $USER
ENV HOME=/home/$USER
COPY welcome $HOME/.welcome
RUN sed -i "s/__GUAC_PORT__/${GUAC_PORT}/g" $HOME/.welcome && \
    sed -i "s/__RDP_USER__/${RDP_USER}/g"  $HOME/.welcome
RUN --mount=type=bind,source=scripts,target=/tmp/scripts \
    bash /tmp/scripts/customize-bashrc.sh

# ── systemd must run as root (PID 1) ─────────────────────────────────────────
USER root
EXPOSE 22 80 ${GUAC_PORT} ${RDP_PORT}
CMD ["/lib/systemd/systemd"]
