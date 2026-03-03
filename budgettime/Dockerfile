# ÉTAPE 1 : Constructeur Go (Builder)
# Permet de compiler le PocketBase + API RSA (Enable Banking)
FROM golang:1.24-alpine AS builder

WORKDIR /app
# On copie les dépendances Go locales
COPY go.mod go.sum ./
RUN go mod download

# On copie le code natif Go (Bridge JWT) et le dossier des scripts js
COPY main.go ./
COPY pb_hooks/ ./pb_hooks/

# Compilation statique du serveur PocketBase Custom (Compatible toute architecture)
RUN CGO_ENABLED=0 go build -o pocketbase main.go

# -------------------------

# ÉTAPE 2 : Image Runtime (Légère et Rapide) 
FROM alpine:latest

# Installation des outils systèmes utiles pour CasaOS / Home Assistant
RUN apk add --no-cache ca-certificates dos2unix tzdata

# Définir le répertoire de travail
WORKDIR /pb

# === NOUVELLE MÉTHODE (Go Natif) ===
# Au lieu de télécharger l'exécutable générique sur internet avec 'curl' et 'unzip',
# nous "aspirons" directement notre propre exécutable depuis l'ÉTAPE 1 (Builder).
COPY --from=builder /app/pocketbase /pb/pocketbase
RUN chmod +x /pb/pocketbase

# On s'assure de récupérer aussi nos scripts Javascript JSVM (pour l'authentification jwt)
COPY --from=builder /app/pb_hooks /pb/pb_hooks

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
