#!/bin/bash
set -e

CONFIG_JSON="/vagrant/provision/conf/email.json"

if [ -f "$CONFIG_JSON" ]; then
    if ! dpkg -l | grep -q jq; then
        apt-get update -y
        apt-get install -y jq
    fi
    RELAY_HOST=$(jq -r '.relay_host' "$CONFIG_JSON")
    RELAY_PORT=$(jq -r '.relay_port' "$CONFIG_JSON")
    SMTP_USER=$(jq -r '.smtp_user' "$CONFIG_JSON")
    SMTP_PASS=$(jq -r '.smtp_pass' "$CONFIG_JSON")
fi

export DEBIAN_FRONTEND=noninteractive

# Installer postfix et dépendances seulement si pas déjà
if ! dpkg -l | grep -q postfix || ! dpkg -l | grep -q libsasl2-modules || ! dpkg -l | grep -q mailutils; then
    apt-get update -y
    apt-get install -y postfix libsasl2-modules mailutils
fi

# Configs Postfix : appliquer seulement si changées
postconf -e "relayhost = [${RELAY_HOST}]:${RELAY_PORT}" || true
postconf -e "smtp_sasl_auth_enable = yes" || true
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" || true
postconf -e "smtp_sasl_security_options = noanonymous" || true
postconf -e "smtp_use_tls = yes" || true
postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" || true

# Fichier sasl_passwd : recréer seulement si différent
NEW_SASL_CONTENT="[${RELAY_HOST}]:${RELAY_PORT}    ${SMTP_USER}:${SMTP_PASS}"
if [ ! -f /etc/postfix/sasl_passwd ] || ! diff -q <(echo "$NEW_SASL_CONTENT") /etc/postfix/sasl_passwd >/dev/null 2>&1; then
    echo "$NEW_SASL_CONTENT" > /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd
fi

# Postmap seulement si .db absent ou fichier changé
if [ ! -f /etc/postfix/sasl_passwd.db ] || [ /etc/postfix/sasl_passwd -nt /etc/postfix/sasl_passwd.db ]; then
    postmap /etc/postfix/sasl_passwd
fi

# Restart seulement si service existe et pas déjà actif
if systemctl is-enabled postfix >/dev/null 2>&1; then
    systemctl restart postfix
fi

echo "[POSTFIX] Relai SMTP configuré pour ${RELAY_HOST}:${RELAY_PORT}"