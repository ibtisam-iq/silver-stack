#!/bin/bash
# =============================================================================
# Dev Machine Rootfs — Bash & Zsh Completions Setup
# All completions written to /etc/bash_completion.d/ (system-wide)
# =============================================================================
set -euo pipefail

BASH_COMP_DIR="/etc/bash_completion.d"
ZSH_COMP_DIR="/usr/share/zsh/vendor-completions"

mkdir -p "${BASH_COMP_DIR}" "${ZSH_COMP_DIR}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[COMP]${NC}  $1"; }
log_phase() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# =============================================================================
# kubectl
# https://kubernetes.io/docs/tasks/tools/included/optional-kubectl-configs-bash-linux/
# =============================================================================
log_phase "kubectl completion"
kubectl completion bash > "${BASH_COMP_DIR}/kubectl"
kubectl completion zsh  > "${ZSH_COMP_DIR}/_kubectl"
log_info "kubectl done"

# =============================================================================
# helm
# https://helm.sh/docs/helm/helm_completion/
# =============================================================================
log_phase "helm completion"
helm completion bash > "${BASH_COMP_DIR}/helm"
helm completion zsh  > "${ZSH_COMP_DIR}/_helm"
log_info "helm done"

# =============================================================================
# terraform
# https://developer.hashicorp.com/terraform/cli/commands#shell-tab-completion
# =============================================================================
log_phase "terraform completion"
terraform -install-autocomplete 2>/dev/null || true
# Also drop a static completion file for bash
cat > "${BASH_COMP_DIR}/terraform" <<'EOF'
complete -C /usr/bin/terraform terraform
EOF
log_info "terraform done"

# =============================================================================
# docker
# Docker ships its own completion file via the package
# =============================================================================
log_phase "docker completion"
# docker-ce installs bash completion at /usr/share/bash-completion/completions/docker
# We symlink into our dir as a safety net
if [ -f /usr/share/bash-completion/completions/docker ]; then
  ln -sf /usr/share/bash-completion/completions/docker "${BASH_COMP_DIR}/docker"
else
  docker completion bash > "${BASH_COMP_DIR}/docker"
fi
docker completion zsh > "${ZSH_COMP_DIR}/_docker"
log_info "docker done"

# =============================================================================
# gh (GitHub CLI)
# https://cli.github.com/manual/gh_completion
# =============================================================================
log_phase "gh completion"
gh completion -s bash > "${BASH_COMP_DIR}/gh"
gh completion -s zsh  > "${ZSH_COMP_DIR}/_gh"
log_info "gh done"

# =============================================================================
# aws (AWS CLI v2)
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html
# =============================================================================
log_phase "aws completion"
cat > "${BASH_COMP_DIR}/aws" <<'EOF'
complete -C '/usr/local/bin/aws_completer' aws
EOF
log_info "aws done"

# =============================================================================
# kustomize
# =============================================================================
log_phase "kustomize completion"
kustomize completion bash > "${BASH_COMP_DIR}/kustomize"
kustomize completion zsh  > "${ZSH_COMP_DIR}/_kustomize"
log_info "kustomize done"

# =============================================================================
# stern
# https://github.com/stern/stern
# =============================================================================
log_phase "stern completion"
stern --completion bash > "${BASH_COMP_DIR}/stern"
stern --completion zsh  > "${ZSH_COMP_DIR}/_stern"
log_info "stern done"

# =============================================================================
# k9s — no built-in completion (TUI tool, not needed)
# kubectx/kubens — completions shipped as separate files in upstream release
# =============================================================================
log_phase "kubectx + kubens completion"
# Bash completions are bundled with kubectx releases as completion scripts
curl -fsSL "https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/kubectx.bash" \
  -o "${BASH_COMP_DIR}/kubectx"
curl -fsSL "https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/kubens.bash" \
  -o "${BASH_COMP_DIR}/kubens"
curl -fsSL "https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/_kubectx.zsh" \
  -o "${ZSH_COMP_DIR}/_kubectx"
curl -fsSL "https://raw.githubusercontent.com/ahmetb/kubectx/master/completion/_kubens.zsh" \
  -o "${ZSH_COMP_DIR}/_kubens"
log_info "kubectx + kubens done"

# =============================================================================
# yq
# https://github.com/mikefarah/yq
# =============================================================================
log_phase "yq completion"
yq shell-completion bash > "${BASH_COMP_DIR}/yq"
yq shell-completion zsh  > "${ZSH_COMP_DIR}/_yq"
log_info "yq done"

# =============================================================================
# trivy
# https://aquasecurity.github.io/trivy
# =============================================================================
log_phase "trivy completion"
trivy completion bash > "${BASH_COMP_DIR}/trivy"
trivy completion zsh  > "${ZSH_COMP_DIR}/_trivy"
log_info "trivy done"

# =============================================================================
# cosign
# =============================================================================
log_phase "cosign completion"
cosign completion bash > "${BASH_COMP_DIR}/cosign"
cosign completion zsh  > "${ZSH_COMP_DIR}/_cosign"
log_info "cosign done"

# =============================================================================
# syft
# =============================================================================
log_phase "syft completion"
syft completion bash > "${BASH_COMP_DIR}/syft"
syft completion zsh  > "${ZSH_COMP_DIR}/_syft"
log_info "syft done"

# =============================================================================
# ansible (argcomplete-based)
# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
# =============================================================================
log_phase "ansible completion"
python3 -m pip install --break-system-packages argcomplete 2>/dev/null || true
activate-global-python-argcomplete --dest="${BASH_COMP_DIR}" 2>/dev/null || true
log_info "ansible done"

# =============================================================================
# pre-commit
# =============================================================================
log_phase "pre-commit completion"
pre-commit complete-bash 2>/dev/null > "${BASH_COMP_DIR}/pre-commit" || \
  register-python-argcomplete pre-commit > "${BASH_COMP_DIR}/pre-commit" 2>/dev/null || true
log_info "pre-commit done"

# =============================================================================
# pip3 completion
# =============================================================================
log_phase "pip3 completion"
pip3 completion --bash > "${BASH_COMP_DIR}/pip3" 2>/dev/null || true
log_info "pip3 done"

# =============================================================================
# npm completion
# =============================================================================
log_phase "npm completion"
npm completion > "${BASH_COMP_DIR}/npm" 2>/dev/null || true
log_info "npm done"

# Fix permissions on all completion files
chmod 644 "${BASH_COMP_DIR}"/* 2>/dev/null || true
chmod 644 "${ZSH_COMP_DIR}"/_* 2>/dev/null || true

log_info "============================================"
log_info "All completions installed."
log_info "============================================"
