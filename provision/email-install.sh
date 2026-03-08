#!/bin/bash
set -e

CONFIG_JSON="/vagrant/provision/conf/email.json"

if [ -f "$CONFIG_JSON" ]; then
  apt-get update -y
  apt-get install -y jq

  RELAY_HOST=$(jq -r '.relay_host' "$CONFIG_JSON")
  RELAY_PORT=$(jq -r '.relay_port' "$CONFIG_JSON")
  SMTP_USER=$(jq -r '.smtp_user' "$CONFIG_JSON")
  SMTP_PASS=$(jq -r '.smtp_pass' "$CONFIG_JSON")
fi

RELAY_HOST="${RELAY_HOST:-smtp.example.com}"
RELAY_PORT="${RELAY_PORT:-587}"
SMTP_USER="${SMTP_USER:-user@example.com}"
SMTP_PASS="${SMTP_PASS:-change_me}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y postfix libsasl2-modules mailutils

postconf -e "relayhost = [${RELAY_HOST}]:${RELAY_PORT}"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"

cat > /etc/postfix/sasl_passwd <<EOF
[${RELAY_HOST}]:${RELAY_PORT}    ${SMTP_USER}:${SMTP_PASS}
EOF

chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd
systemctl restart postfix