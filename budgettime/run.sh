#!/bin/sh

echo "Starting BudgetTime server diagnostic..."
ls -lh /pb/pocketbase
/pb/pocketbase --version

# Génération d'un certificat auto-signé si absent
if [ ! -f "server.crt" ]; then
    echo "Generating self-signed SSL certificate..."
    openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes -subj "/CN=localhost"
fi

# Création du Caddyfile pour le reverse proxy HTTPS
echo ":8090 {
    tls /pb/server.crt /pb/server.key
    reverse_proxy localhost:8080
}" > /pb/Caddyfile

# Lancement de Caddy en arrière-plan
echo "Starting Caddy reverse proxy (HTTPS :8090 -> HTTP :8080)..."
caddy start --config /pb/Caddyfile

# Si le dossier /data existe, on est dans Home Assistant OS
if [ -d "/data" ]; then
    echo "Environment: Home Assistant Add-on (HTTPS with Caddy Proxy)"
    mkdir -p /share/budgettime/secrets
    cd /share/budgettime
    exec /pb/pocketbase serve --http="localhost:8080" --dir="pb_data"
else
    echo "Environment: Docker Standard (HTTPS with Caddy Proxy)"
    mkdir -p /pb/secrets
    cd /pb
    exec /pb/pocketbase serve --http="localhost:8080" --dir="pb_data"
fi
