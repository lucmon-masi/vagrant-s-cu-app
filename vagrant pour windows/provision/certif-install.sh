#!/bin/bash
set -e

echo "[CERTIF] Installation d'une CA locale avec Easy-RSA..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y easy-rsa

# Dossier CA
CA_DIR=/var/local/ca
mkdir -p "$CA_DIR"
chown vagrant:vagrant "$CA_DIR"

# Copier les scripts easy-rsa
cp -r /usr/share/easy-rsa/* "$CA_DIR"
cd "$CA_DIR"

# Init PKI
./easyrsa init-pki <<EOF
EOF

# Vars minimalistes (DN par défaut)
cat > "$CA_DIR/vars" <<EOF
set_var EASYRSA_REQ_COUNTRY    "BE"
set_var EASYRSA_REQ_PROVINCE   "Wallonie"
set_var EASYRSA_REQ_CITY       "Binche"
set_var EASYRSA_REQ_ORG        "LabSec"
set_var EASYRSA_REQ_EMAIL      "admin@labsec.local"
set_var EASYRSA_REQ_OU         "CA"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
EOF

# Construire la CA sans passphrase
./easyrsa --batch build-ca nopass

echo "[CERTIF] CA créée."
echo "[CERTIF] Certificat racine : $CA_DIR/pki/ca.crt"
echo "[CERTIF] Clé privée       : $CA_DIR/pki/private/ca.key"
