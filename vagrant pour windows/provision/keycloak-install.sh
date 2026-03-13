#!/bin/bash
set -e  # Stop sur erreur

echo "=== Installation Keycloak natif Ubuntu 24.04 ==="

apt-get update -y
apt-get install -y openjdk-21-jdk unzip wget gnupg software-properties-common curl postgresql postgresql-contrib

# PostgreSQL sécurisé
systemctl enable --now postgresql
sudo -u postgres psql <<EOF
CREATE DATABASE keycloak;
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'keycloakpassforte';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

\c keycloak
GRANT ALL ON SCHEMA public TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
EOF

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /etc/postgresql/*/main/postgresql.conf
systemctl restart postgresql


# Keycloak 26.5.5
cd /opt
KC_VERSION=26.5.5
KC_URL="https://github.com/keycloak/keycloak/releases/download/${KC_VERSION}/keycloak-${KC_VERSION}.tar.gz"
wget "${KC_URL}"
tar -xzf "keycloak-${KC_VERSION}.tar.gz"
mv "keycloak-${KC_VERSION}" keycloak

# Users
groupadd -r keycloak || true
useradd -r -g keycloak -d /opt/keycloak -s /sbin/nologin keycloak || true
chown -R keycloak:keycloak /opt/keycloak

# Config
cat > /opt/keycloak/conf/keycloak.conf <<EOF
db=postgres
db-url=jdbc:postgresql://127.0.0.1:5432/keycloak
db-username=keycloak
db-password=keycloakpassforte
hostname=keycloak
http-enabled=true
http-port=8080
EOF

# Service systemd
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
systemctl start keycloak

# Bootstrap admin Keycloak 26.x
sleep 30
cd /opt/keycloak
sudo -u keycloak KEYCLOAK_ADMIN_PASSWORD="admin123" \
  ./bin/kc.sh bootstrap-admin user --username admin --password:env KEYCLOAK_ADMIN_PASSWORD --no-prompt

echo "=== Keycloak installé ! http://$(hostname -I | awk '{print $1}'):8080 ==="
