#!/usr/bin/env bash
# =============================================================================
# infra-bootstrap — Kubernetes Version Resolver
#
# Purpose:
#   Resolve an exact Kubernetes patch version from MAJOR.MINOR input
#
# Input (required):
#   K8S_VERSION="1.35"
#
# Output (exported):
#   K8S_MAJOR_MINOR   → 1.35
#   K8S_PATCH_VERSION → 1.35.0
#   K8S_IMAGE_TAG     → v1.35.0
#   KUBE_PKG_VERSION  → 1.35.0-1.1
#
# This script:
#   • performs NO installation
#   • performs NO system modification
#   • is safe to source multiple times
# =============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# --------------------------- Validation ---------------------------
: "${K8S_VERSION:?K8S_VERSION is required (e.g. 1.35)}"

if ! [[ "$K8S_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "[ERR ]    K8S_VERSION must be MAJOR.MINOR (e.g. 1.35). Provided: ${K8S_VERSION}" >&2
  return 1 2>/dev/null || exit 1
fi

# --------------------------- Set Variables ---------------------------
K8S_MAJOR_MINOR="$K8S_VERSION"

# --------------------------- Resolve Patch ---------------------------
STABLE_URL="https://dl.k8s.io/release/stable-${K8S_MAJOR_MINOR}.txt"

echo "[INFO]    Resolving Kubernetes version from: ${STABLE_URL}"

if ! PATCH_TAG="$(curl -fsSL "${STABLE_URL}")"; then
  echo "[ERR ]    Failed to fetch Kubernetes release info for ${K8S_MAJOR_MINOR}" >&2
  return 1 2>/dev/null || exit 1
fi

# Expected format: v1.35.0
if ! [[ "$PATCH_TAG" =~ ^v${K8S_MAJOR_MINOR}\.[0-9]+$ ]]; then
  echo "[ERR ]    Invalid release tag received: ${PATCH_TAG}" >&2
  return 1 2>/dev/null || exit 1
fi

export K8S_VERSION="$K8S_MAJOR_MINOR"               # e.g. 1.35
export K8S_MAJOR_MINOR="$K8S_VERSION"               # e.g. 1.35
export K8S_IMAGE_TAG="${PATCH_TAG}"                 # e.g. v1.35.0
export K8S_PATCH_VERSION="${PATCH_TAG#v}"           # Remove leading 'v'
export KUBE_PKG_VERSION="${K8S_PATCH_VERSION}-1.1"  # Kubernetes deb packages append revision suffix