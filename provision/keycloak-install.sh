#!/bin/bash
set -e  # Stop sur erreur

echo "=== Installation Keycloak natif Ubuntu 24.04 (idempotent) ==="

export DEBIAN_FRONTEND=noninteractive

# Paquets seulement si absents
PACKAGES="openjdk-21-jdk unzip wget gnupg software-properties-common curl postgresql postgresql-contrib"
for pkg in $PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        apt-get update -y
        apt-get install -y $pkg
    fi
done

# PostgreSQL : enable/start si pas actif
if ! systemctl is-enabled --quiet postgresql; then
    systemctl enable --now postgresql
fi

# Config PostgreSQL listen_addresses si pas déjà
PG_CONF="/etc/postgresql/*/main/postgresql.conf"
if ! grep -q "^listen_addresses = 'localhost'" $PG_CONF 2>/dev/null; then
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" $PG_CONF
    systemctl restart postgresql
fi

# DB et user Keycloak : créer seulement si absents
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='keycloak'" | grep -q 1 || \
sudo -u postgres psql <<EOF
CREATE DATABASE keycloak;
EOF

sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='keycloak'" | grep -q 1 || \
sudo -u postgres psql <<EOF
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloakpassforte';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
EOF

sudo -u postgres psql -d keycloak -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" | grep -q "0" || \
sudo -u postgres psql -d keycloak <<EOF
GRANT ALL ON SCHEMA public TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
EOF

# Keycloak 26.5.5 : télécharger seulement si absent
cd /opt
KC_VERSION=26.5.5
KC_DIR="/opt/keycloak"
if [ ! -d "$KC_DIR" ]; then
    KC_URL="https://github.com/keycloak/keycloak/releases/download/${KC_VERSION}/keycloak-${KC_VERSION}.tar.gz"
    wget "${KC_URL}"
    tar -xzf "keycloak-${KC_VERSION}.tar.gz"
    mv "keycloak-${KC_VERSION}" keycloak
    rm "keycloak-${KC_VERSION}.tar.gz"
fi

# Users/groupes
if ! getent group keycloak >/dev/null; then
    groupadd -r keycloak
fi
if ! getent passwd keycloak >/dev/null; then
    useradd -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak
fi
chown -R keycloak:keycloak /opt/keycloak

# Config keycloak.conf : recréer si différent
NEW_CONF_CONTENT="db=postgres
db-url=jdbc:postgresql://127.0.0.1:5432/keycloak
db-username=keycloak
db-password=keycloakpassforte
hostname=keycloak
http-enabled=true
http-port=8080"
if [ ! -f "$KC_DIR/conf/keycloak.conf" ] || ! diff -q <(echo "$NEW_CONF_CONTENT") "$KC_DIR/conf/keycloak.conf" >/dev/null 2>&1; then
    echo "$NEW_CONF_CONTENT" > "$KC_DIR/conf/keycloak.conf"
fi

# Service systemd : créer si absent
if [ ! -f /etc/systemd/system/keycloak.service ]; then
    cat > /etc/systemd/system/keycloak.service <<EOF
[Unit]
Description=Keycloak
After=network.target postgresql.service

[Service]
Type=simple
User=keycloak
Group=keycloak
WorkingDirectory=/opt/keycloak
Environment=KC_BOOTSTRAP_ADMIN_USERNAME=admin
Environment=KC_BOOTSTRAP_ADMIN_PASSWORD=admin123
ExecStart=/opt/keycloak/bin/kc.sh start 
TimeoutStopSec=600
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable keycloak
fi

# Start/restart si pas running
if ! systemctl is-active --quiet keycloak; then
    systemctl start keycloak
fi

# Bootstrap admin seulement si KC pas initialisé (check realm master vide-ish)
sleep 10  # Attente mini
if [ -f "$KC_DIR/data" ] && ! ls "$KC_DIR/data"/*/*master*/ 2>/dev/null | grep -q .; then
    cd /opt/keycloak
    sudo -u keycloak KEYCLOAK_ADMIN_PASSWORD="admin123" \
        ./bin/kc.sh bootstrap-admin user --username admin --password:env KEYCLOAK_ADMIN_PASSWORD --no-prompt
fi

IP=$(hostname -I | awk '{print $1}')
echo "=== Keycloak prêt ! http://${IP}:8080 (admin/admin123) ==="
