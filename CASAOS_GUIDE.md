# Guide d'Installation et Mise à Jour - CasaOS

Ce guide explique comment installer **BudgetTime** sur CasaOS et faciliter les futures mises à jour.

## 1. Préparation de l'Image Docker

Pour que CasaOS puisse télécharger et mettre à jour votre application, l'image Docker doit être hébergée sur un registre public (comme Docker Hub) ou privé.

### Étape A : Choisir son Registre

Vous avez deux options principales :
1. **Docker Hub** : Le plus simple, mais nécessite un compte [hub.docker.com](https://hub.docker.com/).
2. **GitHub Container Registry (GHCR)** : Idéal si vous avez déjà un compte GitHub.

#### Option 1 : Docker Hub
1. Connectez-vous sur votre PC : `docker login`

#### Option 2 : GitHub Container Registry (GHCR)
1. Cliquez sur ce lien direct : [**Créer un Token GitHub**](https://github.com/settings/tokens/new?scopes=write:packages,read:packages,delete:packages&description=BudgetTime-CasaOS).
   - *Si le lien ne fonctionne pas* : Allez dans Settings (en haut à droite) -> Developer settings (tout en bas à gauche) -> Personal access tokens -> Tokens (classic) -> Generate new token (classic).
2. Connectez-vous si demandé.
3. Dans la page "New personal access token" :
   - **Note** : "BudgetTime-CasaOS" (ou autre).
   - **Expiration** : "No expiration" (ou selon votre choix, mais il faudra le refaire s'il expire).
   - **Select scopes** : Vérifiez que **`write:packages`** est coché (le lien le fait pour vous).
4. Cliquez sur **Generate token** (bouton vert tout en bas).
5. **COPIEZ LE TOKEN MAINTENANT** (il commence par `ghp_`...). Vous ne pourrez plus le revoir.
6. Sur votre PC :
   ```powershell
   # Remplacez VOTRE_PSEUDO par votre nom d'utilisateur GitHub
   docker login ghcr.io -u VOTRE_PSEUDO
   # Collez le token quand on vous demande le mot de passe
   ```

### Étape B : Construire et Publier l'Image

J'ai intégré la construction Docker directement dans le script de release.
Désormais, pour mettre à jour l'application ET l'image Docker, lancez simplement :

```powershell
.\release.ps1 -Version X.Y.Z
```
(Remplacez X.Y.Z par votre nouvelle version).

Le script vous demandera à la fin si vous voulez pousser l'image sur Docker Hub/GHCR. Répondez `O` (Oui).
L'image sera automatiquement taguée `ghcr.io/hkdone/budgettime:X.Y.Z` et `latest`.

---

## 2. Installation sur CasaOS

Une fois l'image publiée (ex: `jean/budgettime:latest`), allez sur votre interface CasaOS.

### Option 1 : Installation via "Custom App" (Recommandé)

1. Cliquez sur le bouton **+** (Install a customized app) en haut à gauche.
2. Remplissez les champs :
   - **Docker Image** : `votre-identifiant/budgettime:latest`
   - **Title** : `BudgetTime`
   - **Web UI Port** : `8090` (Port interne)
3. **Network** :
   - **Port HTTP** : Choisissez un port disponible sur votre CasaOS, par exemple `8097`.
     - *Host Port* : `8097`
     - *Container Port* : `8090`
4. **Volumes** (Important pour la persistance) :
   - Cliquez sur `Add Volume` / `+`.
   - **Host Path** : `/DATA/AppData/budgettime/pb_data` (ou chemin de votre choix).
   - **Container Path** : `/pb/pb_data`
   - *Optionnel* : Ajoutez un volume pour `/pb/pb_public` si vous voulez modifier le frontend sans tout redéployer, mais avec l'image Docker ce n'est généralement pas nécessaire.
5. Cliquez sur **Install**.

### Option 2 : Import Docker Compose

Si CasaOS supporte l'import Docker Compose (via l'icône en haut à droite de la fenêtre d'installation) :

1. Créez un fichier `docker-compose.yml` avec ce contenu :

```yaml
version: "3"
services:
  budgettime:
    image: votre-identifiant/budgettime:latest
    container_name: budgettime
    restart: unless-stopped
    ports:
      - "8097:8090"
    volumes:
      - /DATA/AppData/budgettime/pb_data:/pb/pb_data
```
2. Importez-le ou collez-le.

---

## 3. Mettre à Jour l'Application

Quand une nouvelle version est prête (ex: v1.6.0) :

### Sur votre PC de développement :
1. Mettez à jour le code.
2. Lancez `.\deploy_image.ps1`.
3. Validez le push vers Docker Hub. Le tag `:latest` sera mis à jour.

### Sur CasaOS :
1. Ouvrez les paramètres de l'application **BudgetTime**.
2. Dans le champ **Docker Image**, vérifiez qu'il y a bien `:latest` à la fin.
3. CasaOS peut parfois détecter la mise à jour, mais le plus sûr est de :
   - Cliquer sur les `...` de l'app -> **Uninstall** (Ne vous inquiétez pas, les données sont dans `/DATA/AppData/...` et ne sont pas effacées si vous n'avez pas coché "Delete config files" - *Vérifiez bien ce point*).
   - **OU PLUS SIMPLE** : Si vous avez Portainer ou un gestionnaire avancé, faites un "Pull & Recreate".
   - **Méthode CasaOS native** : Souvent, il suffit de changer le tag (ex: de `:latest` à `:1.5.0` puis revenir à `:latest`) ou de redémarrer pour qu'il vérifie le pull, selon la version de CasaOS.
   - **Méthode recommandée** : Cliquez sur Settings -> En haut à droite l'icône de Terminal/Logs -> Tapez `docker pull votre-identifiant/budgettime:latest` si vous avez un accès SSH, puis redémarrez le conteneur.

*Note : Les données (comptes, transactions) sont stockées dans le volume mappé et survivent à la mise à jour du conteneur.*
