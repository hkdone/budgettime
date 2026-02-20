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

## 4. Troubleshooting: Installation Manuelle (Fiable à 100%)
Si vous rencontrez des erreurs de type "Invalid Add-on Repository", voici la méthode manuelle :

1.  Installez l'add-on officiel **File Editor** ou **Samba Share**.
    *   **Si vous utilisez File Editor** : Allez dans la configuration de l'add-on, désactivez `Enforce Basepath` (mettez le à `false`) et redémarrez l'add-on. Ensuite, cliquez sur la flèche "Remonter" (..) en haut de l'explorateur de fichiers pour sortir du dossier `/config` et voir le dossier `/addons`.
    *   **Si vous utilisez Samba Share** : Le dossier `addons` devrait apparaître dans votre réseau Windows.
2.  Dans ce dossier `/addons` (s'il n'existe pas, créez-le à la racine), créez un dossier `local_budgettime`.
4.  À l'intérieur, créez 3 fichiers (`config.yaml`, `Dockerfile`, `run.sh`) avec le contenu suivant :

### config.yaml
```yaml
name: "BudgetTime Local"
version: "1.5.2"
slug: "budgettime_local"
description: "Gestion de budget Offline-First"
url: "https://github.com/hkdone/budgettime"
startup: application
arch:
  - aarch64
  - amd64
# image: "ghcr.io/hkdone/budgettime:{arch}" # Commenté pour forcer le build local
map:
  - "share:rw"
ports:
  8090/tcp: 8090
ports_description:
  8090/tcp: Web Interface
data: true
options: {}
schema: {}
```

### Dockerfile
```dockerfile
FROM ghcr.io/hkdone/budgettime:latest
COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD [ "/run.sh" ]
```

### run.sh
*(Attention : Assurez-vous que les fins de lignes sont en LF / Unix)*
```bash
#!/bin/sh
if [ -d "/data" ]; then
    echo "Environment: Home Assistant Add-on"
    /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/data/pb_data" --publicDir="/pb/pb_public"
else
    echo "Environment: Docker Standard"
    /pb/pocketbase serve --http=0.0.0.0:8090 --dir="/pb/pb_data" --publicDir="/pb/pb_public"
fi
```

### Étape Finale
1.  Redémarrez l'Add-on Store (3 petits points -> "Check for updates").
2.  Dans "Local Add-ons", installez **BudgetTime Local**.

## 5. Méthode "Terminal & SSH" (Si vous ne trouvez pas le dossier addons)
Si vous ne voyez pas le dossier `/addons`, le plus simple est d'utiliser l'add-on **Terminal & SSH** :

1.  Installez et lancez l'add-on **Terminal & SSH**.
2.  Tapez ces commandes (une par une) :

```bash
# Aller dans le dossier addons (le créer s'il n'existe pas)
cd /addons || mkdir /addons && cd /addons

# Télécharger le projet
git clone https://github.com/hkdone/budgettime temp_install

# Déplacer le dossier de l'addon au bon endroit
mv temp_install/budgettime local_budgettime

# Nettoyer
rm -rf temp_install
```

3.  Allez dans **Boutique** -> **Check for updates**.
4.  L'addon **BudgetTime** apparaîtra dans la liste "Local Add-ons".
