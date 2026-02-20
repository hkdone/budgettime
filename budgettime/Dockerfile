FROM alpine:latest

# Arguments de build (Valeurs par défaut pour Synology Intel/AMD)
ARG PB_VERSION=0.22.3
ARG PB_ARCH=linux_amd64

# Installation des outils
RUN apk add --no-cache unzip ca-certificates curl dos2unix libc6-compat

# Téléchargement PocketBase (Gestion d'architecture robuste + Cache Bust)
ARG BUILD_ARCH
# On force une reconstruction complète à chaque changement de version ou de script
RUN echo "Build date: $(date)" > /build_info && \
    REAL_ARCH=${BUILD_ARCH:-$(uname -m)} && \
    echo "Host architecture: $(uname -m)" && \
    echo "Target architecture (HA variable): ${BUILD_ARCH}" && \
    case "${REAL_ARCH}" in \
    "x86_64"|"amd64"|"amd64") PB_BINARY_ARCH="linux_amd64" ;; \
    "aarch64"|"arm64"|"armv8"*) PB_BINARY_ARCH="linux_arm64" ;; \
    "armv7"*|"armhf") PB_BINARY_ARCH="linux_armv7" ;; \
    *) echo "Architecture ${REAL_ARCH} non reconnue, utilisation par défaut: linux_arm64" && PB_BINARY_ARCH="linux_arm64" ;; \
    esac && \
    echo "Selected PocketBase Binary: ${PB_BINARY_ARCH}" && \
    curl -L -f "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_${PB_BINARY_ARCH}.zip" -o /tmp/pb.zip && \
    unzip -o /tmp/pb.zip -d /pb/ && \
    chmod +x /pb/pocketbase && \
    # Vérification du type de binaire
    echo "Binary Info: $(file /pb/pocketbase 2>/dev/null || echo 'Binaire ELF détecté')" && \
    head -c 4 /pb/pocketbase | grep -q $'\x7fELF' && echo "Verification success: ELF Magic Found" || (echo "FATAL: Invalid binary format" && exit 1) && \
    rm /tmp/pb.zip

# Copie du Frontend Flutter
COPY pb_public /pb/pb_public

# Script de lancement
COPY run.sh /run.sh
RUN dos2unix /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
