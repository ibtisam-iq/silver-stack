#!/bin/bash
set -euo pipefail

#######################################################################
# customize-bashrc.sh — SilverStack Dev Machine
#
# Appends SilverStack stack aliases to the dev user's .bashrc.
#
# Author: Muhammad Ibtisam Iqbal
#######################################################################

cat <<'EOF' >> $HOME/.bashrc

# SilverStack stack aliases
alias stack-jenkins='ssh -o StrictHostKeyChecking=no ibtisam@jenkins-server'
alias stack-sonarqube='ssh -o StrictHostKeyChecking=no ibtisam@sonarqube-server'
alias stack-nexus='ssh -o StrictHostKeyChecking=no ibtisam@nexus-server'

# Navigation
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

echo "✓ Bashrc customized successfully"
