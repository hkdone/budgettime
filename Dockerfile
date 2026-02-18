FROM alpine:latest

# Installation des outils
RUN apk add --no-cache unzip ca-certificates curl

# Téléchargement PocketBase (Version ARM64 pour Raspberry Pi/CasaOS)
# Remplacer par AMD64 si serveur Intel/AMD
ADD https://github.com/pocketbase/pocketbase/releases/download/v0.22.3/pocketbase_0.22.3_linux_arm64.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/

# Copie du Frontend Flutter (c'est ici que l'injection se fait)
# Assurez-vous d'avoir exécuté `flutter build web --web-renderer html` avant
COPY pb_public /pb/pb_public

# Script de lancement
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8090

CMD ["/run.sh"]
