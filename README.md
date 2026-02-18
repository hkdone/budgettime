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

### 2. Déploiement (Docker / CasaOS)

Le déploiement se fait via une image Docker contenant à la fois le Backend (PocketBase) et le Frontend (Flutter Web).

1.  **Compiler l'application** :
    ```powershell
    ./release.ps1 -Version "1.0.1" -Message "Nouvelle version"
    ```
    *Ce script compile le frontend, met à jour le backend, et prépare les fichiers pour Docker.*

2.  **Construire et Lancer le conteneur** :
    ```bash
    docker-compose up -d --build
    ```

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
