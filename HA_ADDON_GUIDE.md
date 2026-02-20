# Guide d'Installation - Home Assistant Add-on

Ce guide explique comment installer **BudgetTime** directement dans Home Assistant (HAOS) en tant qu'Add-on.

## Pré-requis

- Une installation Home Assistant OS (HAOS) ou Supervised.
- L'image Docker doit être publique (voir [CASAOS_GUIDE.md](file:///c:/Users/dkdone/StudioProjects/budgettime/CASAOS_GUIDE.md)).

## Méthode : Repository GitHub

La méthode la plus propre pour installer un Add-on personnalisé est d'ajouter votre dépôt GitHub comme "Add-on Repository" dans Home Assistant.

### 1. Préparer le Dépôt (Déjà fait par le script)

Le fichier `config.yaml` à la racine de votre projet contient les informations nécessaires pour Home Assistant.
Il indique notamment d'utiliser l'image Docker `ghcr.io/hkdone/budgettime`.

### 2. Ajouter le Dépôt dans Home Assistant

1. Ouvrez **Home Assistant**.
2. Allez dans **Paramètres** -> **Modules complémentaires** (Add-ons).
3. Cliquez sur le bouton **Boutique des modules complémentaires** (Add-on Store) en bas à droite.
4. Cliquez sur les **3 petits points** en haut à droite -> **Dépôts** (Repositories).
5. Ajoutez l'URL de votre dépôt GitHub :
   `https://github.com/hkdone/budgettime`
6. Cliquez sur **Ajouter**.

### 3. Installer l'Add-on

1. Une fois le dépôt ajouté, rechargez la page ou descendez tout en bas de la boutique.
2. Vous devriez voir une nouvelle section avec **BudgetTime**.
3. Cliquez dessus, puis cliquez sur **Installer**.
4. Une fois installé :
   - Activez **Afficher dans la barre latérale**.
   - Activez **Protection** (si vous voulez).
   - Cliquez sur **Démarrer**.

### 4. Accès

L'application sera accessible :
- Via le menu latéral de Home Assistant (Iframe).
- Ou directement sur le port `8090` de votre serveur HA (ex: `http://homeassistant.local:8090`).

## Mises à Jour

Quand vous publiez une nouvelle version (via `release.ps1`) :
1. Dans Home Assistant, allez sur la page de l'Add-on.
2. Vous devriez voir un bouton de mise à jour (parfois il faut "Rechercher les mises à jour" dans la boutique).
3. Cliquez sur **Mettre à jour**.
