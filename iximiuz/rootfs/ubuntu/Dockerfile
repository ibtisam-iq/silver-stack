# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG ARKADE_BIN_DIR
ARG BTOP_VERSION
ARG CFSSL_VERSION
ARG USER
ARG WEBSOCAT_VERSION
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="Ubuntu 24.04 Rootfs" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

COPY --from=ubuntu:22.04 /usr/local/sbin/unminimize /usr/local/sbin/unminimize

# udev is needed for booting a "real" VM, setting up the ttyS0 console properly
# kmod is needed for modprobing modules
RUN <<EOF
set -eu

apt-get update
apt-get upgrade -y

apt-get install -y \
  bash-completion \
  bzip2 \
  ca-certificates \
  curl \
  dbus \
  dnsutils \
  file \
  gettext-base \
  git \
  gnupg \
  htop \
  iproute2 \
  iptables \
  iputils-ping \
  kmod \
  locales \
  lsb-release \
  lsof \
  make \
  man \
  mtr \
  netcat-openbsd \
  net-tools \
  nftables \
  psmisc \
  ripgrep \
  socat \
  sudo \
  systemd \
  traceroute \
  tree \
  udev \
  unzip \
  vim \
  wget

yes | unminimize

# Doesn't seem to be needed and produces extra noise in journald.
systemctl mask networkd-dispatcher.service

rm -rf /etc/update-motd.d/*
rm -f /.dockerenv

# Create the following files, but unset them.
echo "" > /etc/machine-id && echo "" > /var/lib/dbus/machine-id

echo "root:root" | chpasswd
EOF

RUN <<EOF
set -eu

apt-get update
apt-get install -y openssh-server

echo "HostKey /etc/ssh/ssh_host_ed25519_key" >> /etc/ssh/sshd_config
echo "AuthenticationMethods publickey" >> /etc/ssh/sshd_config
echo "PrintLastLog no" >> /etc/ssh/sshd_config
echo "AddressFamily inet" >> /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config
echo "MaxAuthTries 50" >> /etc/ssh/sshd_config

systemctl mask sshd-keygen@.service
systemctl mask sshd-keygen.target

systemctl disable ssh.socket
rm -f /etc/systemd/system/ssh.service.d/00-socket.conf
rm -f /etc/systemd/system/ssh.socket.d/addresses.conf
systemctl enable ssh.service

rm -f /etc/ssh/ssh_host_*
EOF


COPY examiner* /usr/local/bin
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/set-up-systemd-examiner-service.sh


# System-wide shell prompt (inherited by all images built on this base)
COPY configs/profile.d/00-prompt.sh /etc/profile.d/00-prompt.sh
RUN chmod +x /etc/profile.d/00-prompt.sh


# System-wide user tools.
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-arkade.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-common-tools.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-btop.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-cfssl.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-websocat.sh
RUN curl https://fx.wtf/install.sh | sh


# User-specific tools - root
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-fzf.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/customize-bashrc.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/customize-git.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/customize-vimrc.sh


# Add the user.
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/add-user.sh

USER $USER
ENV HOME=/home/$USER

COPY welcome $HOME/.welcome

# User-specific tools - $USER
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-code-server.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/get-fzf.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/customize-bashrc.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts USER=$USER /tmp/scripts/customize-git.sh
RUN --mount=type=bind,source=scripts,target=/tmp/scripts /tmp/scripts/customize-vimrc.sh
