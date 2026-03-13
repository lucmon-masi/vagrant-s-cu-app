#!/bin/bash
set -e

echo "[*] Mise à jour des paquets..."
sudo apt-get update -y

echo "[*] Installation de Nginx..."
sudo apt-get install -y nginx

echo "[*] Activation et démarrage du service Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "[*] Création d'une page index.html de test..."
sudo mkdir -p /var/www/web-vm
sudo chown -R "$USER":"$USER" /var/www/web-vm

cat > /var/www/web-vm/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>VM Web - OK</title>
</head>
<body>
    <h1>VM Web : Nginx fonctionne</h1>
    <p>Servi depuis /var/www/web-vm sur port 80.</p>
</body>
</html>
EOF

echo "[*] Configuration du vhost Nginx..."
sudo tee /etc/nginx/sites-available/web-vm >/dev/null << 'EOF'
server {
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
}
EOF

echo "[*] Activation du vhost et désactivation du site par défaut..."
sudo ln -sf /etc/nginx/sites-available/web-vm /etc/nginx/sites-enabled/web-vm
sudo rm -f /etc/nginx/sites-enabled/default

echo "[*] Test de la configuration Nginx..."
sudo nginx -t

echo "[*] Reload de Nginx..."
sudo systemctl reload nginx

echo "[*] Installation terminée. Teste avec : curl http://<IP_VM>"
