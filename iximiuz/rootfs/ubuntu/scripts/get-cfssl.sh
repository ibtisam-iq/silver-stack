#!/bin/sh
set -eu

if [ -z "${CFSSL_VERSION:-}" ]; then
  echo "CFSSL_VERSION must be set"
  exit 1
fi

# Detect host architecture and map to cfssl release naming
case "$(uname -m)" in
  x86_64)  CFSSL_ARCH="amd64" ;;
  aarch64) CFSSL_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

DIR=$(mktemp -d)
cd "${DIR}"

curl -fsSL --remote-name-all https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/{cfssl-bundle,cfssl-certinfo,cfssl-newkey,cfssl-scan,cfssljson,cfssl,mkbundle,multirootca}_${CFSSL_VERSION}_linux_${CFSSL_ARCH}

for src in *_${CFSSL_VERSION}_linux_${CFSSL_ARCH}; do
  dst="${src%_${CFSSL_VERSION}_linux_${CFSSL_ARCH}}"
  mv "${src}" "${dst}"
  chmod +x "${dst}"
  mv "${dst}" /usr/bin
done

cd ..
rm -rf "${DIR}"
