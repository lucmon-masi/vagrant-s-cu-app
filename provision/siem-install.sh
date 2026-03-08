#!/bin/bash
set -e

# Petit log
echo "[SIEM] Installation de Wazuh (all-in-one)..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl apt-transport-https unzip wget libcap2-bin \
  software-properties-common lsb-release gnupg2

# Télécharger le script officiel Wazuh (version 4.x)
# Tu peux figer la version si tu veux (ex: 4.7) au lieu de 4.14
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh

chmod +x wazuh-install.sh

# Installation all-in-one (indexer + manager + dashboard)
sudo bash ./wazuh-install.sh -a

echo "[SIEM] Installation Wazuh terminée."
echo "[SIEM] Les identifiants et URL sont dans /var/log/wazuh-install.log et dans wazuh-install-files.tar"
