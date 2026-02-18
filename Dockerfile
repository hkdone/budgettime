FROM alpine:latest

# Installation des outils
RUN apk add --no-cache unzip ca-certificates curl

# Arguments de build (Valeurs par défaut pour Synology Intel/AMD)
ARG PB_VERSION=0.22.3
ARG PB_ARCH=linux_amd64

# Téléchargement PocketBase
ADD https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_${PB_ARCH}.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/

# Copie du Frontend Flutter (c'est ici que l'injection se fait)
# Assurez-vous d'avoir exécuté `flutter build web --web-renderer html` avant
COPY pb_public /pb/pb_public

# Script de lancement
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
