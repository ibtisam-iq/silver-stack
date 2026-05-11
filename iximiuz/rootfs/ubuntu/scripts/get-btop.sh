#!/bin/sh
set -eu

if [ -z "${BTOP_VERSION:-}" ]; then
  echo "BTOP_VERSION must be set"
  exit 1
fi

# Detect host architecture and map to btop release naming
case "$(uname -m)" in
  x86_64)  BTOP_ARCH="x86_64" ;;
  aarch64) BTOP_ARCH="aarch64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

DIR=$(mktemp -d)

curl -Ls "https://github.com/aristocratos/btop/releases/download/v${BTOP_VERSION}/btop-${BTOP_ARCH}-linux-musl.tbz" | tar -xjf - -C "${DIR}"

cd "${DIR}/btop"
make install
cd /

rm -rf "${DIR}"
