#!/bin/bash
set -e

echo "[CERTIF] Installation d'une CA locale avec Easy-RSA..."

export DEBIAN_FRONTEND=noninteractive

# Idempotent: installer seulement si pas déjà installé
if ! dpkg -l | grep -q easy-rsa; then
    apt-get update -y
    apt-get install -y easy-rsa
fi

# Dossier CA
CA_DIR=/var/local/ca
if [ ! -d "$CA_DIR" ]; then
    mkdir -p "$CA_DIR"
    chown vagrant:vagrant "$CA_DIR"
fi

# Copier les scripts easy-rsa seulement si pas déjà présents
if [ ! -d "$CA_DIR/pki" ]; then
    cp -r /usr/share/easy-rsa/* "$CA_DIR"
fi
cd "$CA_DIR"

# Init PKI seulement si pas déjà initialisé
if [ ! -d "$CA_DIR/pki" ]; then
    ./easyrsa init-pki
fi

# Vars minimalistes (surcharge/overwrite si existe)
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

# Construire la CA seulement si pas déjà existante (vérif ca.crt)
if [ ! -f "$CA_DIR/pki/ca.crt" ]; then
    ./easyrsa --batch build-ca nopass
fi

echo "[CERTIF] CA prête."
echo "[CERTIF] Certificat racine : $CA_DIR/pki/ca.crt"
echo "[CERTIF] Clé privée       : $CA_DIR/pki/private/ca.key"
