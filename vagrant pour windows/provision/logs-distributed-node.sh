#!/bin/bash
set -e

echo "[LOGS-DIST] Installation rsyslog node (server+client) (idempotent)..."

export DEBIAN_FRONTEND=noninteractive

# Paquets seulement si absents
for pkg in rsyslog jq; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        apt-get update -y
        apt-get install -y $pkg
    fi
done

CONFIG_JSON="/vagrant/provision/conf/logs.json"
HOSTNAME="$(hostname)"

if [ ! -f "$CONFIG_JSON" ]; then
    echo "[LOGS-DIST] Fichier de config $CONFIG_JSON introuvable, arrêt."
    exit 1
fi

# Récupérer la liste des peers
PEER_LIST=$(jq -r --arg host "$HOSTNAME" '.[$host].peers | join(",")' "$CONFIG_JSON")
echo "[LOGS-DIST] Host: $HOSTNAME, peers: $PEER_LIST"

RSYSLOG_CONF="/etc/rsyslog.conf"

# Activer imtcp seulement si commenté
if ! grep -q '^module(load="imtcp")' "$RSYSLOG_CONF"; then
    sed -i 's/^#module(load="imtcp")/module(load="imtcp")/' "$RSYSLOG_CONF"
fi
if ! grep -q '^input(type="imtcp" port="514")' "$RSYSLOG_CONF"; then
    sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/' "$RSYSLOG_CONF"
fi

# Dossiers logs
for dir in /var/log/remote /var/log/node; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chown syslog:adm "$dir"
    fi
done

# Templates remote/node : recréer seulement si différent
REMOTE_TEMPLATE_CONTENT='$template PeerLogs,"/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?PeerLogs'
if [ ! -f /etc/rsyslog.d/10-remote-peers.conf ] || ! diff -q <(echo "$REMOTE_TEMPLATE_CONTENT") /etc/rsyslog.d/10-remote-peers.conf >/dev/null 2>&1; then
    echo "$REMOTE_TEMPLATE_CONTENT" > /etc/rsyslog.d/10-remote-peers.conf
fi

NODE_TEMPLATE_CONTENT='$template NodeLogs,"/var/log/node/%PROGRAMNAME%.log"
*.* ?NodeLogs'
if [ ! -f /etc/rsyslog.d/10-node-local.conf ] || ! diff -q <(echo "$NODE_TEMPLATE_CONTENT") /etc/rsyslog.d/10-node-local.conf >/dev/null 2>&1; then
    echo "$NODE_TEMPLATE_CONTENT" > /etc/rsyslog.d/10-node-local.conf
fi

# Forward vers peers : générer et appliquer seulement si changé
NEW_FORWARD_CONTENT='# Forward vers les pairs'
if [ -n "$PEER_LIST" ]; then
    IFS=',' read -ra PEERS <<< "$PEER_LIST"
    NEW_FORWARD_CONTENT+=$'\n'"$ActionQueueType LinkedList"
    NEW_FORWARD_CONTENT+=$'\n'"$ActionQueueFileName distFwd"
    NEW_FORWARD_CONTENT+=$'\n'"$ActionResumeRetryCount -1"
    NEW_FORWARD_CONTENT+=$'\n'"$ActionQueueSaveOnShutdown on"
    for peer in "${PEERS[@]}"; do
        NEW_FORWARD_CONTENT+=$'\n'"*.* @@${peer}:514"
    done
fi

FORWARD_CONF="/etc/rsyslog.d/50-forward-peers.conf"
if [ ! -f "$FORWARD_CONF" ] || ! diff -q <(echo "$NEW_FORWARD_CONTENT") "$FORWARD_CONF" >/dev/null 2>&1; then
    echo "$NEW_FORWARD_CONTENT" > "$FORWARD_CONF"
fi

# Restart seulement si pas actif ou configs changées (ici toujours après conf)
systemctl restart rsyslog
systemctl enable rsyslog

echo "[LOGS-DIST] Node prêt. Logs locaux: /var/log/node, remote: /var/log/remote/"
