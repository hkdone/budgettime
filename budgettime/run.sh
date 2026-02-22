#!/bin/sh

echo "Starting BudgetTime server diagnostic..."
ls -lh /pb/pocketbase
/pb/pocketbase --version

# Si le dossier /data existe, on est dans Home Assistant OS
if [ -d "/data" ]; then
    echo "Environment: Home Assistant Add-on"
    echo "Data will be stored in /share/budgettime for user visibility"
    # On pointe vers le dossier share pour que l'utilisateur puisse le voir/vider
    mkdir -p /share/budgettime
    exec /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/share/budgettime/pb_data" --publicDir="/pb/pb_public"
else
    echo "Environment: Docker Standard"
    # On pointe vers le volume monté standard
    exec /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/pb/pb_data" --publicDir="/pb/pb_public"
fi
