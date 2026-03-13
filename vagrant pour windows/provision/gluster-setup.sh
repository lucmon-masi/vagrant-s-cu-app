#!/bin/bash
set -e

CONFIG_JSON="/vagrant/provision/conf/gluster-config.json"

VOL_NAME=$(jq -r '.volume_name' "$CONFIG_JSON")
BRICK_DIR=$(jq -r '.brick_dir' "$CONFIG_JSON")
MOUNT_DIR=$(jq -r '.mount_dir' "$CONFIG_JSON")
HOSTNAME_SHORT=$(hostname -s)

NODE_ROLE=$(jq -r ".nodes[] | select(.name == \"$HOSTNAME_SHORT\") | .role" "$CONFIG_JSON")
PRIMARY_IP=$(jq -r '.nodes[] | select(.role == "primary") | .ip' "$CONFIG_JSON")
ALL_IPS=($(jq -r '.nodes[].ip' "$CONFIG_JSON"))

echo "[*] $(date) - Noeud: $HOSTNAME_SHORT (role: $NODE_ROLE)"
echo "    Volume: $VOL_NAME, Brick: $BRICK_DIR, Mount: $MOUNT_DIR, Primary: $PRIMARY_IP"

echo "[*] Installation (ou vérif) GlusterFS + client..."
sudo apt-get update -y
sudo apt-get install -y glusterfs-server glusterfs-client jq
sudo systemctl enable --now glusterd

# Brick locale
sudo mkdir -p "$BRICK_DIR"
sudo chown -R root:root "$BRICK_DIR"

mount_with_retry() {
  local target_dir="$1"
  local server="$2"
  local vol="$3"

  sudo mkdir -p "$target_dir"

  for i in {1..5}; do
    if mountpoint -q "$target_dir"; then
      echo "    [$HOSTNAME_SHORT] $target_dir déjà monté."
      return 0
    fi

    echo "    [$HOSTNAME_SHORT] Tentative de mount $i/5..."
    if sudo mount -t glusterfs ${server}:/$vol "$target_dir"; then
      echo "    [$HOSTNAME_SHORT] Mount OK."
      return 0
    fi

    sleep 2
  done

  echo "[!] [$HOSTNAME_SHORT] Impossible de monter $vol sur $target_dir après plusieurs tentatives."
  return 1
}

if [ "$NODE_ROLE" = "primary" ]; then
  echo "[*] Mode PRIMARY - configuration du cluster et du volume"

  # Peer probe vers les autres noeuds (idempotent)
  for ip in "${ALL_IPS[@]}"; do
    [ "$ip" = "$PRIMARY_IP" ] && continue
    echo "    peer probe $ip"
    sudo gluster peer probe "$ip" || true
  done

  echo "[*] Attente des peers..."
  sleep 5
  sudo gluster peer status || true

  # Création du volume si inexistant
  if ! sudo gluster volume info "$VOL_NAME" >/dev/null 2>&1; then
    echo "[*] Création du volume $VOL_NAME..."
    BRICKS=()
    for ip in "${ALL_IPS[@]}"; do
      BRICKS+=("${ip}:${BRICK_DIR}")
    done

    sudo gluster volume create "$VOL_NAME" replica ${#ALL_IPS[@]} \
      "${BRICKS[@]}" force

    sudo gluster volume start "$VOL_NAME"
  else
    echo "[*] Volume $VOL_NAME existe déjà, on ne le recrée pas."
  fi

  echo "[*] Volume $VOL_NAME prêt :"
  sudo gluster volume info "$VOL_NAME"

  echo "[*] Montage du volume sur $HOSTNAME_SHORT..."
  mount_with_retry "$MOUNT_DIR" "$PRIMARY_IP" "$VOL_NAME"
  sudo chown -R vagrant:vagrant "$MOUNT_DIR" || true
  echo "[*] PRIMARY prêt, volume monté sur $MOUNT_DIR."

else
  echo "[*] Mode SECONDARY - rejoindre le cluster"

  # Peer probe vers primary (idempotent)
  echo "    peer probe $PRIMARY_IP"
  sudo gluster peer probe "$PRIMARY_IP" || true

  echo "[*] Attente que le volume $VOL_NAME existe sur le primary..."
  for i in {1..30}; do
    if sudo gluster volume info "$VOL_NAME" >/dev/null 2>&1; then
      echo "    Volume $VOL_NAME trouvé."
      break
    fi
    sleep 2
  done

  echo "[*] Montage du volume sur $HOSTNAME_SHORT..."
  mount_with_retry "$MOUNT_DIR" "$PRIMARY_IP" "$VOL_NAME"
  sudo chown -R vagrant:vagrant "$MOUNT_DIR" || true
  echo "[*] SECONDARY prêt, volume monté sur $MOUNT_DIR."
fi
