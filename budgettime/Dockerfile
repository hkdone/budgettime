# ÉTAPE 1 : Compilation du binaire (Builder multi-architecture pour HA/CasaOS)
FROM golang:alpine AS builder

# Dépendances nécessaires pour la compilation
RUN apk add --no-cache git tzdata

WORKDIR /app

# Optimiser le cache Docker en téléchargeant d'abord les dépendances
COPY go.mod go.sum ./
RUN go mod download

# Copier le code source
COPY main.go ./

# Compilation statique du backend (CGO_ENABLED=0 garantit une compatibilité totale sans libs externes)
RUN CGO_ENABLED=0 go build -o /pocketbase main.go

# ÉTAPE 2 : Image Runtime (Légère et Rapide) 
FROM alpine:latest

# Installation des outils systèmes utiles pour CasaOS / Home Assistant
RUN apk add --no-cache ca-certificates dos2unix tzdata openssl caddy

# Définir le répertoire de travail
WORKDIR /pb

# === MÉTHODE MULTI-STAGE ===
# On récupère le binaire compilé à l'étape 1
COPY --from=builder /pocketbase /pb/pocketbase
RUN chmod +x /pb/pocketbase

# Copie du Frontend Flutter
COPY pb_public /pb/pb_public

# Copie des Migrations PocketBase
COPY pb_migrations /pb/pb_migrations

# Création du dossier pour les secrets (Enable Banking)
RUN mkdir -p /pb/secrets

# Script de lancement
COPY run.sh /run.sh
RUN dos2unix /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
