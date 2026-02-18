# BudgetTime

Application de gestion de budget "Offline-First" hébergée via PocketBase, conçue pour Docker et Home Assistant.

## Fonctionnalités Clés
- **Multi-Comptes**: Gestion de plusieurs comptes bancaires.
- **Budget Prévisionnel**: Vue "Mois Glissant" basée sur votre jour de paie (ex: du 20 au 19).
- **Récurrences Intelligentes**: Projection automatique des frais fixes sur 1 an.
- **Inbox Processor**: Importation automatique depuis des notifications via Home Assistant.
- **100% Local**: Vos données restent chez vous (PocketBase).

## Guide de Démarrage Rapide

### 1. Développement Local
```powershell
# Installation des dépendances
flutter pub get

# Lancer en mode debug (Chrome)
flutter run -d chrome
```

### 2. Déploiement (Synology / Docker Compose)

1.  **Compiler l'application** (sur votre PC) :
    ```powershell
    ./release.ps1 -Version "1.0.1" -Message "Nouvelle version"
    ```

2.  **Sur votre Synology** :
    *   Installez **Container Manager** (ou Docker).
    *   Créez un dossier `budget-app` via File Station.
    *   Copiez-y tous les fichiers du projet (notamment `Dockerfile`, `docker-compose.yml`, `run.sh` et le dossier `pb_public`).
    *   **Architecture** : Le `Dockerfile` est par défaut en `linux_amd64` (Intel/AMD). Si vous avez un Synology ARM (ex: DS220j), modifiez la ligne `ARG PB_ARCH=linux_arm64` dans le Dockerfile.

3.  **Lancer via Container Manager** :
    *   Allez dans **Projet** > **Créer**.
    *   Nom: `budget-app`.
    *   Chemin: Sélectionnez votre dossier `budget-app`.
    *   Source: "Utiliser docker-compose.yml existant".
    *   Suivant > Suivant > Terminé.

    *   Suivant > Suivant > Terminé.

L'application sera accessible sur `http://IP_NAS:8097` (si vous avez utilisé le port 8097).
**Interface Admin PocketBase** : `http://IP_NAS:8097/_/`

### Troubleshooting Synology
- **Crash Loop / Redémarrage en boucle** :
  - Vérifiez que vous avez copié le dossier `pb_public` complet.
  - Le problème vient souvent des retours à la ligne Windows (CRLF) dans `run.sh`. Le Dockerfile utilise `dos2unix` pour régler ça automatiquement, assurez-vous de bien reconstruire l'image.
  - Vérifiez l'architecture (AMD64 vs ARM64) dans le Dockerfile.

### 3. Déploiement (Home Assistant)

Pour installer en tant qu'Add-on Home Assistant :

1.  Assurez-vous que le projet est sur un dépôt GitHub accessible.
2.  Dans Home Assistant > Modules complémentaires > Boutique > Ajouter un dépôt (URL de votre Git).
3.  Installez "Budget Assistant".
4.  Le fichier `config.yaml` à la racine définit la version. Le script `release.ps1` met à jour cette version automatiquement.

## Scripts Utiles

- `local_dev_setup.ps1` : Initialisation rapide pour le dev local.
- `release.ps1` : Workflow complet de release (Build Web -> Update Version -> Git Commit -> Git Tag).

## Architecture
- **Frontend**: Flutter Web (Clean Architecture, Riverpod, GoRouter).
- **Backend**: PocketBase (Binaire Go inclus dans l'image Docker).
- **Base de données**: SQLite (géré par PocketBase).
