#!/bin/bash
set -euo pipefail

#######################################################################
# customize-bashrc.sh
#
# Appends SonarQube, PostgreSQL, and Nginx aliases to the lab user's .bashrc.
# Base image handles all other shell customizations.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

cat <<'EOF' >> $HOME/.bashrc

# SonarQube aliases
alias sonar-status='sudo systemctl status sonarqube'
alias sonar-logs='sudo journalctl -u sonarqube -f --no-pager'
alias sonar-restart='sudo systemctl restart sonarqube'
alias sonar-start='sudo systemctl start sonarqube'
alias sonar-stop='sudo systemctl stop sonarqube'

# PostgreSQL aliases
alias pg-status='sudo systemctl status postgresql'
alias pg-logs='sudo journalctl -u postgresql -f --no-pager'
alias pg-restart='sudo systemctl restart postgresql'

# Nginx aliases
alias nginx-status='sudo systemctl status nginx'
alias nginx-logs='sudo tail -f /var/log/nginx/sonarqube-access.log'
alias nginx-reload='sudo systemctl reload nginx'

# Navigation
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

echo "✓ Bashrc customized successfully"
