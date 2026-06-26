# Guide de déploiement — BudgetTime

Ce document décrit comment publier et mettre à jour BudgetTime sur vos **3 environnements** : Synology, CasaOS et Home Assistant.

> **Principe clé** : un seul build Flutter Web est produit. La différenciation entre environnements se fait au **runtime** (`run.sh`, volumes Docker) — pas de flavors Flutter ni de builds séparés.

---

## Prérequis PC (Windows, après réinstallation)

`release.ps1` a besoin de **3 outils** obligatoires et **1 optionnel** :

| Outil | Obligatoire | Rôle dans `release.ps1` | Installation |
|-------|:-----------:|-------------------------|--------------|
| **Flutter** | ✅ | `flutter build web` (étape 3) | [flutter.dev](https://docs.flutter.dev/get-started/install/windows) — ajouter au PATH |
| **Go** | ✅ | `go build` → binaire Linux `pocketbase` (étape 4) | [go.dev/dl](https://go.dev/dl/) — version **≥ 1.22** (le projet utilise 1.25.x) |
| **Git** | ✅ | commit + tag local (étape 5) | [git-scm.com](https://git-scm.com/download/win) |
| **Docker** | ❌ pour test Synology | build/push GHCR — seulement si vous répondez **o** | Docker Desktop (optionnel) |

### Vérifier que tout est installé

```powershell
flutter --version    # doit répondre (SDK 3.10+)
go version           # doit répondre (go1.22+)
git --version        # doit répondre
```

Dans le dossier du projet, une seule fois après clone / réinstall PC :

```powershell
cd C:\Users\jeanv\Desktop\Projets\StudioProjects\budgettime
flutter pub get
go mod download
```

### Go — pourquoi c'est nécessaire

`release.ps1` compile `main.go` en binaire **Linux AMD64** pour votre Synology :

```powershell
$env:GOOS = "linux"
$env:GOARCH = "amd64"
go build -o budgettime/pocketbase main.go
```

Sans Go installé, l'étape 4 du script échoue. Flutter seul ne suffit pas.

### Flutter — première utilisation

Si `flutter doctor` signale des problèmes, exécutez :

```powershell
flutter doctor
flutter doctor --android-licenses   # seulement si build Android (pas requis pour BudgetTime Web)
```

Pour BudgetTime Web + Synology, il faut surtout **Chrome** (pour `flutter run -d chrome`) et le toolchain Web activé :

```powershell
flutter config --enable-web
```

---

## Étape 0 — Release sur votre PC (Windows)

Toute mise à jour commence ici :

```powershell
./release.ps1 -Version "2.4.18" -Message "Description de la mise à jour"
```

Le script effectue automatiquement :

1. Bump de version (`pubspec.yaml`, `budgettime/config.yaml`, UI login/dashboard, `web/index.html`)
2. Build Flutter Web → copie dans `budgettime/pb_public/`
3. Copie des sources Go (`main.go`, `go.mod`, `go.sum`, `docker-compose.yml`) dans `budgettime/`
4. Compilation du binaire Linux `budgettime/pocketbase` (pour Synology)
5. Commit Git + tag `v{version}`

Ensuite, le script pose **deux questions** :

| Question | Synology seul | CasaOS | Home Assistant | Les 3 |
|----------|:-------------:|:------:|:--------------:|:-----:|
| Push GitHub ? | Non requis | Optionnel | **Oui** | **Oui** |
| Build & Push Docker (GHCR) ? | Non requis | **Oui** | Non requis | **Oui** |

Image Docker publiée : `ghcr.io/hkdone/budgettime:latest` et `ghcr.io/hkdone/budgettime:{version}`

---

## Test privé sur votre Synology (avant publication publique)

Votre Synology est l'environnement idéal pour valider une version **sans impacter** CasaOS (GHCR), Home Assistant (GitHub) ni les autres utilisateurs.

### Principe

| Action | Test Synology seul | Publication pour tout le monde |
|--------|:------------------:|:------------------------------:|
| Build local (`release.ps1` étapes 1–4) | ✅ | ✅ |
| Copie `budgettime/` → NAS | ✅ | Optionnel (Synology perso) |
| Push GitHub | ❌ Répondre **n** | ✅ Répondre **o** |
| Push Docker GHCR | ❌ Répondre **n** | ✅ Répondre **o** |
| `git pull` sur HA / Update CasaOS | ❌ Non touché | ✅ |

Tant que vous répondez **n** aux deux questions de `release.ps1`, personne d'autre ne reçoit la mise à jour.

### Workflow recommandé pour tester sur Synology (sans publier)

```powershell
./release.ps1 -Version "2.4.18-test1" -Message "Test Synology — Sprint 1"
```

Quand le script demande :

- **Push to GitHub now?** → `n`
- **Build and Push Docker image now?** → `n`

Puis copiez le contenu de `budgettime/` sur le NAS et redémarrez le conteneur.

> C'est la méthode recommandée : un seul script, build complet, rien n'est publié pour les autres utilisateurs.

### Workflow recommandé (3 étapes)

#### Étape A — Développement rapide (PC)

```powershell
flutter run -d chrome
```

Pour tester le backend Go custom sans Docker :

```powershell
go run main.go serve --http=127.0.0.1:8090 --dir=pb_data
```

> Le PocketBase de `local_dev_setup.ps1` (v0.22.3) n'est pas identique à la prod (v0.36.5). Pour un test backend fidèle, préférez `go run main.go`.

#### Étape B — Build « candidat » pour le NAS

```powershell
./release.ps1 -Version "2.4.18-test1" -Message "Test Synology — rapprochement inbox"
```

Quand le script demande :

- **Push to GitHub now?** → `n`
- **Build and Push Docker image now?** → `n`

Vous obtenez un dossier `budgettime/` prêt, commité **en local** seulement.

**Alternative sans bump de version** (itération rapide pendant le dev) — nécessite Flutter + Go installés :

```powershell
flutter build web --release --no-tree-shake-icons
# Copier build\web\* → budgettime\pb_public\
$env:CGO_ENABLED="0"; $env:GOOS="linux"; $env:GOARCH="amd64"
go build -o budgettime/pocketbase main.go
```

Pas de commit, pas de changement de version — idéal entre deux tests sur le NAS.

#### Étape C — Déploiement sur le NAS

1. **Sauvegarder** `pb_data/` sur le Synology (File Station → copier le dossier, ou snapshot Btrfs si disponible).
2. Copier depuis le PC (`budgettime/` après `release.ps1`) :

| Élément | Copier ? | Rôle |
|---------|:--------:|------|
| **`pb_public/`** | ✅ Presque toujours | Frontend Flutter compilé |
| **`pocketbase`** | ✅ Si backend Go modifié | Binaire serveur Linux |
| **`pb_migrations/`** | ✅ Si nouvelle migration | Schéma base (ex. champ `origin`) |
| `run.sh`, `Dockerfile` | Parfois | Config conteneur |
| **`pb_data/`** | ❌ **Jamais écraser** | Vos données |
| **`secrets/`** | ❌ **Jamais écraser** | Clés Enable Banking |

3. Container Manager → **Redémarrer** le conteneur (rebuild seulement si `Dockerfile` changé).
4. Ouvrir `https://IP_NAS:8097` — vérifier la version sur l'écran de login.

### Instance de staging (optionnel, recommandé pour migrations risquées)

Créer un **deuxième projet** Docker sur le NAS, par exemple :

| | Production | Staging / test |
|--|------------|----------------|
| Dossier | `docker/budget-app/` | `docker/budget-app-test/` |
| Port | `8097:8090` | `8098:8090` |
| Données | `pb_data/` réelles | Copie de `pb_data/` ou base vide |

Cela permet de tester migrations PocketBase et changements de solde sans toucher vos vraies données.

### Checklist avant publication publique

- [ ] Testé sur Synology avec vos vraies données (ou copie récente)
- [ ] Boîte de réception / rapprochement OK
- [ ] Solde cohérent (avec et sans sync bancaire si vous l'utilisez)
- [ ] Récurrences et dashboard OK
- [ ] Relancer `release.ps1` avec version **finale** (sans `-test`)
- [ ] Push GitHub → **o** (Home Assistant)
- [ ] Push Docker GHCR → **o** (CasaOS)
- [ ] `git pull` + réinstall HA si vous l'utilisez aussi

### Rollback sur Synology

Si une version test pose problème :

1. Arrêter le conteneur
2. Restaurer l'ancien `pocketbase` et/ou `pb_public/` (gardez une copie `_backup/` sur le NAS)
3. Si `pb_data` corrompu : restaurer la sauvegarde de l'étape C
4. Redémarrer le conteneur

---

## 1. Synology (Container Manager)

**Méthode** : copie manuelle des fichiers — pas de Git, pas de registry.

### Première installation

1. Sur le NAS, créer un dossier (ex. `docker/budget-app/`)
2. Copier **tout le contenu** du dossier `budgettime/` depuis votre PC :
   - `docker-compose.yml`, `Dockerfile`, `run.sh`
   - `pb_public/` (frontend compilé)
   - `pb_migrations/`
   - `pocketbase` (binaire Linux)
   - Créer `secrets/` et y déposer vos clés Enable Banking (`.pem`)
3. Container Manager → **Projet** → Créer → sélectionner le dossier → utiliser le `docker-compose.yml` existant
4. Accès : `https://IP_NAS:8097` (port externe 8097 → interne 8090 HTTPS via Caddy)

### Mise à jour

1. Lancer `release.ps1` sur le PC (push Git et Docker **non requis** si Synology seul)
2. Recopier sur le NAS les éléments modifiés :
   - `pb_public/` ← **toujours**
   - `pocketbase` ← si le backend Go a changé
   - `pb_migrations/` ← si nouvelles migrations
   - `run.sh`, `Dockerfile` ← si le conteneur a changé
3. **Ne jamais écraser** :
   - `pb_data/` (vos données SQLite)
   - `secrets/` (vos clés bancaires)
4. Container Manager → reconstruire l'image ou redémarrer le conteneur

> **Architecture** : le `Dockerfile` compile pour `linux/amd64`. Sur un NAS ARM (ex. DS220j), adapter le build Go dans `release.ps1` (`GOARCH=arm64`) ou utiliser le build multi-stage du `Dockerfile`.

---

## 2. CasaOS

**Méthode** : image Docker hébergée sur le **GitHub Container Registry (GHCR)**.

### Première installation

1. Dans CasaOS, installer BudgetTime (ou créer un conteneur custom)
2. Image : `ghcr.io/hkdone/budgettime:latest`
3. Port : `8097:8090`
4. Monter des volumes pour la persistance : `pb_data`, `secrets`, etc.

### Mise à jour

1. Sur le PC : lancer `release.ps1` et répondre **Oui** à « Build and Push Docker »
2. Vérifier que l'image est bien poussée :
   ```powershell
   docker login ghcr.io   # si nécessaire
   ```
3. Sur CasaOS : cliquer **Update** / **Mettre à jour** sur l'application
4. Si la nouvelle version n'apparaît pas : forcer un **Recreate** / redémarrage du conteneur

> CasaOS et Synology utilisent la **même image Docker** et le même `run.sh`. Seule la méthode d'obtention de l'image diffère (pull GHCR vs copie locale).

---

## 3. Home Assistant (Add-on)

**Méthode** : dépôt Git (`repository.yaml` à la racine, add-on dans `budgettime/config.yaml`).

### Première installation

1. Home Assistant → **Modules complémentaires** → **Boutique** → menu ⋮ → **Dépôts**
2. Ajouter : `https://github.com/hkdone/budgettime`
3. Installer l'add-on **BudgetTime**
4. Démarrer → accès sur le port `8090`

### Mise à jour

1. Sur le PC : lancer `release.ps1` et répondre **Oui** au push GitHub
2. Sur Home Assistant, en SSH :

```bash
cd /addons/budgettime_repo
git pull
```

> Le chemin exact peut varier selon votre installation. Cherchez le dossier où HA a cloné le dépôt.

3. Dans HA :
   - **Boutique** → ⋮ → **Vérifier les mises à jour**
   - Page BudgetTime → **Réinstaller** (ou **Mettre à jour** si disponible)

> Vos données sont persistantes dans `/share/budgettime/pb_data` — elles survivent à la réinstallation.

---

## Récapitulatif rapide

| Instance | Après `release.ps1` | Données persistantes |
|----------|---------------------|----------------------|
| **Synology** | Copier `budgettime/` → NAS, redémarrer Docker | `./pb_data/` sur le NAS |
| **CasaOS** | Cliquer Update dans CasaOS | Volumes Docker |
| **Home Assistant** | `git pull` en SSH + Réinstaller l'add-on | `/share/budgettime/` |

---

## Développement local (rappel)

```powershell
# Option rapide
flutter run -d chrome

# Option complète (build web + PocketBase local)
./local_dev_setup.ps1
```

- Backend local : `pocketbase.exe` v0.22.3 sur `http://127.0.0.1:8090` (HTTP, pas HTTPS)
- Le backend de production est compilé depuis `main.go` (PocketBase v0.36.5)

---

## Gestionnaires de mots de passe (Bitwarden, Proton Pass)

BudgetTime expose un formulaire de login compatible autofill (Flutter + formulaire HTML de secours dans `web/index.html`).

### Enregistrer l'entrée dans le coffre

L'URL enregistrée doit correspondre **exactement** à celle utilisée au quotidien :

| Accès | URL à enregistrer |
|-------|-------------------|
| Navigateur Synology | `https://192.168.x.x:8097` (votre IP + port) |
| PWA installée | L'URL affichée lors de l'installation (souvent la même, mais origine distincte) |

> **Piège fréquent** : une entrée enregistrée pour `https://mon-nas.local:8097` ne remplit pas `https://192.168.1.50:8097` (et inversement). Créez une entrée par URL réellement utilisée.

### Utilisation

1. Ouvrir la page de login BudgetTime.
2. Cliquer dans le champ **Email** — l'extension propose le remplissage.
3. Si rien n'apparaît : utiliser le raccourci de l'extension (icône Bitwarden / Proton Pass → « Remplir »).
4. Après une connexion réussie, le navigateur ou l'extension peut proposer d'**enregistrer** le mot de passe.

### Limites connues

- **Certificat auto-signé** : certaines extensions refusent l'autofill tant que le certificat n'est pas accepté / ajouté aux exceptions.
- **Flutter Web** : l'autofill dépend du navigateur et de l'extension ; le formulaire HTML caché améliore la détection mais ne garantit pas 100 % des cas.
- **PWA vs onglet** : traiter comme deux « sites » distincts pour le coffre si l'autofill ne fonctionne que dans l'un des deux.

---

## Dépannage courant

| Problème | Cause probable | Solution |
|----------|----------------|----------|
| Conteneur Synology en boucle | `run.sh` avec fins de ligne Windows (CRLF) | Reconstruire l'image (`dos2unix` dans le Dockerfile) |
| Page blanche après MAJ | `pb_public/` incomplet | Recopier tout le dossier `pb_public/` |
| CasaOS ne prend pas la MAJ | Cache image `latest` | Forcer recreate du conteneur |
| HA ne voit pas la nouvelle version | Dépôt pas à jour | `git pull` dans `/addons/budgettime_repo` puis « Vérifier les mises à jour » |
| Erreur Docker push | Non authentifié GHCR | `docker login ghcr.io` |

---

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `release.ps1` | Pipeline de release complet |
| `budgettime/` | Artefact de déploiement (HA + Docker + Synology) |
| `budgettime/run.sh` | Détection HA vs Docker + Caddy HTTPS |
| `budgettime/config.yaml` | Manifest Home Assistant Add-on |
| `budgettime/Dockerfile` | Build multi-stage Go → Alpine |
| `repository.yaml` | Enregistrement du dépôt add-on HA |
