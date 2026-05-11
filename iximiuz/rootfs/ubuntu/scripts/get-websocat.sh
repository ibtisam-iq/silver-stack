#!/bin/sh
set -eu

if [ -z "${WEBSOCAT_VERSION:-}" ]; then
  echo "WEBSOCAT_VERSION must be set"
  exit 1
fi

# Detect host architecture and map to websocat release naming
case "$(uname -m)" in
  x86_64)  WS_ARCH="x86_64-unknown-linux-musl" ;;
  aarch64) WS_ARCH="aarch64-unknown-linux-musl" ;;
  *)
    echo "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

curl -sLo /usr/local/bin/websocat "https://github.com/vi/websocat/releases/download/v${WEBSOCAT_VERSION}/websocat.${WS_ARCH}"
chmod 755 /usr/local/bin/websocat
