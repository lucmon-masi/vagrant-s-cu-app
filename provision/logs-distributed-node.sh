#!/bin/bash
set -e

echo "[LOGS-DIST] Installation rsyslog node (server+client)..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y rsyslog jq

CONFIG_JSON="/vagrant/provision/conf/logs.json"
HOSTNAME="$(hostname)"

if [ ! -f "$CONFIG_JSON" ]; then
  echo "[LOGS-DIST] Fichier de config $CONFIG_JSON introuvable, arrêt."
  exit 1
fi

# Récupérer la liste des peers pour ce hostname sous forme "ip1,ip2"
PEER_LIST=$(jq -r --arg host "$HOSTNAME" '.[$host].peers | join(",")' "$CONFIG_JSON")

echo "[LOGS-DIST] Host: $HOSTNAME, peers: $PEER_LIST"

RSYSLOG_CONF="/etc/rsyslog.conf"

# Activer réception TCP 514
sed -i 's/^#module(load="imtcp")/module(load="imtcp")/' "$RSYSLOG_CONF"
sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/' "$RSYSLOG_CONF"

mkdir -p /var/log/remote /var/log/node
chown syslog:adm /var/log/remote /var/log/node

cat > /etc/rsyslog.d/10-remote-peers.conf <<'EOF'
$template PeerLogs,"/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?PeerLogs
EOF

cat > /etc/rsyslog.d/10-node-local.conf <<'EOF'
$template NodeLogs,"/var/log/node/%PROGRAMNAME%.log"
*.* ?NodeLogs
EOF

# Forward vers les peers
if [ -n "$PEER_LIST" ]; then
  IFS=',' read -ra PEERS <<< "$PEER_LIST"
  {
    echo '# Forward vers les pairs'
    echo '$ActionQueueType LinkedList'
    echo '$ActionQueueFileName distFwd'
    echo '$ActionResumeRetryCount -1'
    echo '$ActionQueueSaveOnShutdown on'
    for peer in "${PEERS[@]}"; do
      echo "*.* @@${peer}:514"
    done
  } > /etc/rsyslog.d/50-forward-peers.conf
fi

systemctl restart rsyslog
systemctl enable rsyslog

echo "[LOGS-DIST] Node prêt. Logs locaux: /var/log/node, peers: /var/log/remote/"
