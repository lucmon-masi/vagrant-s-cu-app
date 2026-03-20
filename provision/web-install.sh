#!/bin/bash
set -e

echo "[*] Installation Nginx (idempotent)..."

export DEBIAN_FRONTEND=noninteractive

# Update seulement si nécessaire (paquets changés)
if ! apt list --upgradable 2>/dev/null | grep -q .; then
    apt-get update -y
fi

# Nginx seulement si absent
if ! dpkg -l | grep -q "^ii  nginx "; then
    apt-get install -y nginx
fi

# Service : enable/start si pas déjà
if ! systemctl is-enabled --quiet nginx; then
    systemctl enable nginx
fi
if ! systemctl is-active --quiet nginx; then
    systemctl start nginx
fi

# Dossier et page index
WEB_DIR="/var/www/web-vm"
if [ ! -d "$WEB_DIR" ]; then
    mkdir -p "$WEB_DIR"
    chown -R "$USER":"$USER" "$WEB_DIR"
fi

INDEX_CONTENT='<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>VM Web - OK</title>
</head>
<body>
    <h1>VM Web : Nginx fonctionne</h1>
    <p>Servi depuis /var/www/web-vm sur port 80.</p>
</body>
</html>'
if [ ! -f "$WEB_DIR/index.html" ] || ! diff -q <(echo "$INDEX_CONTENT") "$WEB_DIR/index.html" >/dev/null 2>&1; then
    echo "$INDEX_CONTENT" > "$WEB_DIR/index.html"
fi

# Vhost config : appliquer seulement si différent
VHOST_CONTENT='server {
    listen 80;
    listen [::]:80;

    server_name _;

    root /var/www/web-vm;
    index index.html;

    access_log /var/log/nginx/web-vm.access.log;
    error_log  /var/log/nginx/web-vm.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}'
VHOST_SRC="/etc/nginx/sites-available/web-vm"
if [ ! -f "$VHOST_SRC" ] || ! diff -q <(echo "$VHOST_CONTENT") "$VHOST_SRC" >/dev/null 2>&1; then
    echo "$VHOST_CONTENT" | tee "$VHOST_SRC" >/dev/null
fi

# Lien symbolique vhost : créer seulement si absent ou cassé
VHOST_LINK="/etc/nginx/sites-enabled/web-vm"
if [ ! -L "$VHOST_LINK" ] || [ ! -e "$VHOST_LINK" ]; then
    ln -sf "$VHOST_SRC" "$VHOST_LINK"
fi

# Site default : supprimer seulement si présent
DEFAULT_LINK="/etc/nginx/sites-enabled/default"
if [ -L "$DEFAULT_LINK" ]; then
    rm -f "$DEFAULT_LINK"
fi

# Test config et reload seulement si nécessaire
if ! nginx -t; then
    echo "[*] Erreur config Nginx, correction nécessaire."
    exit 1
fi

if [ -n "$(nginx -t 2>&1 | grep -i warning\|error)" ]; then
    systemctl reload nginx
else
    systemctl reload-or-restart nginx
fi

IP=$(hostname -I | awk '{print $1}')
echo "[*] Nginx prêt ! Teste : curl http://${IP}"
