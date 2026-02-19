# Guide de Déploiement - BudgetTime

Ce guide explique comment mettre à jour votre instance BudgetTime (v1.2.2+).

## Pré-requis

- Avoir accès aux fichiers générés dans le dossier `pb_public/` sur votre machine de développement.
- Avoir accès à votre serveur (SSH, SFTP, ou interface de gestion de fichiers comme CasaOS).

## Check-list de Mise à Jour (Update)

Si vous mettez à jour une installation existante :

1.  **Stop** : Arrêtez votre conteneur Docker.
2.  **Backup** (Optionnel mais recommandé) : Copiez votre dossier `pb_data` actuel en lieu sûr.
3.  **Deploy Frontend** :
    - Supprimez le contenu du dossier `pb_public/` sur votre **serveur**.
    - Copiez le contenu du dossier `pb_public/` de votre **machine de dév** vers le serveur.
    - *Astuce* : Vérifiez que le fichier `version.json` sur le serveur contient bien la bonne version.
4.  **Deploy Schema** (Si nécessaire) :
    - Copiez le dossier `pb_migrations/` vers votre serveur (au même niveau que `pb_public`).
5.  **Start** : Redémarrez votre conteneur.
6.  **Browser Cache** :
    - **CRITIQUE** : Videz le cache de votre navigateur (Ctrl+F5 ou Cmd+Shift+R) ou testez en navigation privée.
    - L'application Web est souvent mise en cache agressivement par les navigateurs.

## Installation Initiale (Docker / CasaOS)

1.  Créez un dossier pour l'application.
2.  Copiez-y :
    - `docker-compose.yml`
    - `pb_public/` (Dossier complet)
    - `pb_migrations/` (Dossier complet)
3.  Lancez le conteneur (`docker-compose up -d`).
4.  Accédez à l'interface admin (`/_/`) pour créer votre premier compte admin.

## Dépannage "Je vois toujours l'ancienne version"

Si après mise à jour, le numéro de version ou les icônes ne changent pas :

1.  Ouvrez votre navigateur.
2.  Allez sur `http://votre-ip:port/version.json`.
3.  Si ce fichier affiche `1.2.2`, alors le serveur est à jour -> **C'est le cache de votre navigateur**.
4.  Si ce fichier affiche `1.1.0` (ou erreur), alors le déploiement des fichiers a échoué -> **Vérifiez votre copie de fichiers**.
