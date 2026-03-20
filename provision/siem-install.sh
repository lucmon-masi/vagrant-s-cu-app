#!/bin/bash
set -e

echo "[SIEM] Installation de Wazuh (all-in-one) (idempotent)..."

export DEBIAN_FRONTEND=noninteractive

# Paquets seulement si absents
PACKAGES="curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg2"
for pkg in $PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        apt-get update -y
        apt-get install -y $pkg
    fi
done

WAZUH_VERSION="4.14"
WAZUH_SCRIPT="wazuh-install.sh"
WAZUH_URL="https://packages.wazuh.com/${WAZUH_VERSION}/${WAZUH_SCRIPT}"

# Télécharger script seulement si absent ou différent
if [ ! -f "$WAZUH_SCRIPT" ] || ! curl -s "$WAZUH_URL" | diff -q - "$WAZUH_SCRIPT" >/dev/null 2>&1; then
    curl -sO "$WAZUH_URL"
    chmod +x "$WAZUH_SCRIPT"
fi

# Check si Wazuh déjà installé (services actifs)
if command -v wazuh-control >/dev/null 2>&1 && wazuh-control status | grep -q "Status.*:running"; then
    echo "[SIEM] Wazuh all-in-one déjà installé et actif."
elif systemctl is-active --quiet wazuh-manager 2>/dev/null && \
     systemctl is-active --quiet wazuh-indexer 2>/dev/null && \
     systemctl is-active --quiet wazuh-dashboard 2>/dev/null; then
    echo "[SIEM] Wazuh services déjà actifs (all-in-one installé)."
else
    echo "[SIEM] Installation Wazuh all-in-one..."
    sudo bash ./wazuh-install.sh -a
fi

echo "[SIEM] Wazuh prêt ! Logs/IDs: /var/log/wazuh-install.log et wazuh-install-files.tar"
echo "[SIEM] Dashboard: https://$(hostname -I | awk '{print $1}')"
