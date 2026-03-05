#!/bin/sh

echo "Starting BudgetTime server diagnostic..."
ls -lh /pb/pocketbase
/pb/pocketbase --version

# Génération d'un certificat auto-signé si absent (Nécessaire pour le mode Production Enable Banking)
if [ ! -f "server.crt" ]; then
    echo "Generating self-signed SSL certificate..."
    openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes -subj "/CN=localhost"
fi

# Si le dossier /data existe, on est dans Home Assistant OS
if [ -d "/data" ]; then
    echo "Environment: Home Assistant Add-on (HTTPS Mode)"
    echo "Data will be stored in /share/budgettime for user visibility"
    mkdir -p /share/budgettime
    cd /share/budgettime
    # On s'assure que les certs sont accessibles depuis le dossier de données si nécessaire ou on relie
    exec /pb/pocketbase serve --https="0.0.0.0:8090" --cert="/pb/server.crt" --key="/pb/server.key" --dir="pb_data"
else
    echo "Environment: Docker Standard (HTTPS Mode)"
    cd /pb
    exec /pb/pocketbase serve --https="0.0.0.0:8090" --cert="/pb/server.crt" --key="/pb/server.key" --dir="pb_data"
fi
