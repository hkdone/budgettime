FROM alpine:latest

# Arguments de build (Valeurs par défaut pour Synology Intel/AMD)
ARG PB_VERSION=0.22.3
ARG PB_ARCH=linux_amd64

# Installation des outils
RUN apk add --no-cache unzip ca-certificates curl dos2unix libc6-compat

# Téléchargement PocketBase (Utilisation de BUILD_ARCH fourni par HA)
ARG BUILD_ARCH
RUN echo "Building for architecture: ${BUILD_ARCH}" && \
    case "${BUILD_ARCH}" in \
    "amd64") PB_BINARY_ARCH="linux_amd64" ;; \
    "aarch64") PB_BINARY_ARCH="linux_arm64" ;; \
    "armv7"|"armhf") PB_BINARY_ARCH="linux_armv7" ;; \
    *) echo "Architecture ${BUILD_ARCH} non supportée par PocketBase" && exit 1 ;; \
    esac && \
    echo "Downloading PocketBase for ${PB_BINARY_ARCH}..." && \
    curl -L -f "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_${PB_BINARY_ARCH}.zip" -o /tmp/pb.zip && \
    unzip /tmp/pb.zip -d /pb/ && \
    chmod +x /pb/pocketbase && \
    rm /tmp/pb.zip

# Copie du Frontend Flutter
COPY pb_public /pb/pb_public

# Script de lancement
COPY run.sh /run.sh
RUN dos2unix /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
