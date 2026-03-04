#!/bin/bash
set -euo pipefail

#######################################################################
# customize-bashrc.sh
#
# Appends Nexus and Nginx aliases to the lab user's .bashrc.
# Base image handles all other shell customizations.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

cat <<'EOF' >> $HOME/.bashrc

# Nexus aliases
alias nexus-status='sudo systemctl status nexus'
alias nexus-logs='sudo journalctl -u nexus -f --no-pager'
alias nexus-restart='sudo systemctl restart nexus'
alias nexus-start='sudo systemctl start nexus'
alias nexus-stop='sudo systemctl stop nexus'

# Nginx aliases
alias nginx-status='sudo systemctl status nginx'
alias nginx-logs='sudo tail -f /var/log/nginx/nexus-access.log'
alias nginx-reload='sudo systemctl reload nginx'

# Navigation
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

echo "✓ Bashrc customized successfully"

