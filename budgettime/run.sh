#!/bin/sh

echo "Starting BudgetTime server diagnostic..."
ls -lh /pb/pocketbase
/pb/pocketbase --version

# Si le dossier /data existe, on est dans Home Assistant OS
if [ -d "/data" ]; then
    echo "Environment: Home Assistant Add-on"
    # On pointe vers le stockage persistant de HA
    exec /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/data/pb_data" --publicDir="/pb/pb_public"
else
    echo "Environment: Docker Standard"
    # On pointe vers le volume monté standard
    exec /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/pb/pb_data" --publicDir="/pb/pb_public"
fi
