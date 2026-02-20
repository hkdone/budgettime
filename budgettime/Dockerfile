FROM alpine:latest

# Arguments de build (Valeurs par défaut pour Synology Intel/AMD)
ARG PB_VERSION=0.22.3
ARG PB_ARCH=linux_amd64

# Installation des outils
# dos2unix est CRUCIAL pour convertir le script run.sh s'il a été édité sur Windows
RUN apk add --no-cache unzip ca-certificates curl dos2unix

# Téléchargement PocketBase (Détection d'architecture automatique)
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
    x86_64) PB_BINARY_ARCH="linux_amd64" ;; \
    aarch64) PB_BINARY_ARCH="linux_arm64" ;; \
    armv7*) PB_BINARY_ARCH="linux_armv7" ;; \
    *) echo "Architecture non supportée: $ARCH" && exit 1 ;; \
    esac && \
    curl -L https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_${PB_BINARY_ARCH}.zip -o /tmp/pb.zip && \
    unzip /tmp/pb.zip -d /pb/ && \
    rm /tmp/pb.zip

# Copie du Frontend Flutter
COPY pb_public /pb/pb_public

# Script de lancement
COPY run.sh /run.sh
RUN dos2unix /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
