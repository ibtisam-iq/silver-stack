#!/bin/bash
set -euo pipefail
#######################################################################
# customize-bashrc.sh
# Appends Guacamole/XRDP/MariaDB/Tomcat/nginx aliases and the
# welcome banner trigger to the interactive user's ~/.bashrc.
# Runs as the interactive user (not root) during Docker build.
# Author: Muhammad Ibtisam Iqbal
#######################################################################

BASHRC="${HOME}/.bashrc"

cat >> "${BASHRC}" << 'EOF'

# ── Guacamole Desktop Playground ─────────────────────────────────────────────
if [ -f ~/.welcome ] && [ -z "${WELCOME_SHOWN:-}" ]; then
    cat ~/.welcome
    export WELCOME_SHOWN=1
fi

# Service shortcuts
alias guac-status='sudo systemctl status guacd tomcat10 mariadb xrdp nginx --no-pager'
alias guac-restart='sudo systemctl restart guacd tomcat10'
alias guac-logs='sudo journalctl -u tomcat10 -f'
alias guacd-logs='sudo journalctl -u guacd -f'
alias xrdp-logs='sudo journalctl -u xrdp -f'
alias nginx-logs='sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log'

# Quick DB access
alias guac-db='sudo mysql guacamole_db'
alias guac-connections="sudo mysql guacamole_db -e 'SELECT connection_id, connection_name, protocol FROM guacamole_connection;'"

# Config shortcuts
alias guac-conf='sudo cat /etc/guacamole/guacamole.properties'
alias guac-props='sudo vim /etc/guacamole/guacamole.properties'
alias nginx-conf='sudo cat /etc/nginx/sites-available/guacamole'

# Port summary
alias ports='ss -lntp | grep -E "22|80|3389|4822|8080|3306"'
EOF

echo "✓ bashrc customized for $(whoami)"
