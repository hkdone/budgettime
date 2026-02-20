#!/bin/sh

# Si le dossier /data existe, on est dans Home Assistant OS
if [ -d "/data" ]; then
    echo "Environment: Home Assistant Add-on"
    # On pointe vers le stockage persistant de HA
    /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/data/pb_data" --publicDir="/pb/pb_public"
else
    echo "Environment: Docker Standard"
    # On pointe vers le volume monté standard
    /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/pb/pb_data" --publicDir="/pb/pb_public"
fi
