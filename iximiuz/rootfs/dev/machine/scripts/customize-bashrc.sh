#!/bin/bash
# =============================================================================
# Dev Machine Rootfs — .bashrc additions
# NOTE: Base image (ubuntu-24-04-rootfs) already handles:
#   - HISTSIZE, locale, EDITOR, GPG_TTY, bash_completion, fzf+rg, PS1, .welcome
# This script ONLY adds what is new to this image.
# =============================================================================

cat <<'EOF' >> "$HOME/.bashrc"

# ─── kubectl aliases ─────────────────────────────────────────────────────────
alias k='kubectl'
complete -o default -F __start_kubectl k
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgd='kubectl get deployments'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kdp='kubectl describe pod'
alias kns='kubens'
alias kctx='kubectx'
alias klog='kubectl logs -f'
alias kexec='kubectl exec -it'

# ─── Docker aliases ──────────────────────────────────────────────────────────
alias d='docker'
complete -F $(complete -p docker 2>/dev/null | awk '{print $(NF-1)}') d 2>/dev/null || truealias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dprune='docker system prune -af'
alias dc='docker compose'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dclogs='docker compose logs -f'

# ─── Git aliases ─────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'

# ─── Terraform aliases ───────────────────────────────────────────────────────
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfv='terraform validate'
alias tff='terraform fmt'

# ─── General utilities ───────────────────────────────────────────────────────
alias ll='ls -alFh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias ports='ss -tulnp'
alias myip='curl -s https://ipinfo.io/ip && echo'
alias paths='echo $PATH | tr ":" "\n"'

EOF
