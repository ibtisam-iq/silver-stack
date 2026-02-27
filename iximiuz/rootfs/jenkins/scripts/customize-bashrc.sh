#!/bin/bash
set -euo pipefail

#######################################################################
# customize-bashrc.sh
#
# Appends Jenkins and Nginx aliases to the lab user's .bashrc.
# Base image handles all other shell customizations.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

cat <<'EOF' >> $HOME/.bashrc

# Jenkins aliases
alias jenkins-status='sudo systemctl status jenkins'
alias jenkins-logs='sudo journalctl -u jenkins -f --no-pager'
alias jenkins-restart='sudo systemctl restart jenkins'
alias jenkins-start='sudo systemctl start jenkins'
alias jenkins-stop='sudo systemctl stop jenkins'

# Nginx aliases
alias nginx-status='sudo systemctl status nginx'
alias nginx-logs='sudo tail -f /var/log/nginx/jenkins-access.log'
alias nginx-reload='sudo systemctl reload nginx'

# Navigation
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

echo "✓ Bashrc customized successfully"
