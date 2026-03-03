# ÉTAPE 1 : Image Runtime (Légère et Rapide) 
FROM alpine:latest

# Installation des outils systèmes utiles pour CasaOS / Home Assistant
RUN apk add --no-cache ca-certificates dos2unix tzdata

# Définir le répertoire de travail
WORKDIR /pb

# === MÉTHODE LOCALE (Go Natif Pré-compilé) ===
# Le script release.ps1 cross-compile "pocketbase" en amont pour Linux
# Nous n'avons qu'à l'aspirer du dossier actuel
COPY pocketbase /pb/pocketbase
RUN chmod +x /pb/pocketbase

# On s'assure de récupérer aussi nos scripts Javascript JSVM
COPY pb_hooks /pb/pb_hooks

# Définir le répertoire de travail pour PocketBase
WORKDIR /pb

# Copie du Frontend Flutter
COPY pb_public /pb/pb_public

# Copie des Migrations PocketBase
COPY pb_migrations /pb/pb_migrations

# Script de lancement
COPY run.sh /run.sh
RUN dos2unix /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
