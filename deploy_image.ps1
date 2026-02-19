# Script de déploiement d'image Docker pour BudgetTime

param (
    [string]$ImageName,
    [string]$Version
)

# Récupérer la version si non fournie
if (-not $Version) {
    if (Test-Path pubspec.yaml) {
        $Version = Select-String -Path "pubspec.yaml" -Pattern "^version: (.*)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
        Write-Host "Version détectée depuis pubspec.yaml: $Version" -ForegroundColor Cyan
    }
    else {
        $Version = Read-Host "Entrez la version de l'image (ex: 1.5.0)"
    }
}

if (-not $ImageName) {
    Write-Host "Nom de l'image requis (ex: votre-compte/budgettime)" -ForegroundColor Yellow
    $ImageName = Read-Host "Nom de l'image (>)"
}

if (-not $ImageName) {
    Write-Error "Nom de l'image obligatoire."
    exit 1
}

# Force lowercase (requis par Docker/GHCR)
$ImageName = $ImageName.ToLower()

# 1. Vérification Docker
docker --version
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker n'est pas installé ou détecté."
    exit 1
}

# 2. Build de l'image
Write-Host "Construction de l'image $($ImageName):$($Version) ..." -ForegroundColor Green
docker build -t "$($ImageName):$($Version)" -t "$($ImageName):latest" .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec du build Docker."
    exit 1
}

# 3. Push vers le registre
Write-Host "Voulez-vous pousser l'image vers le registre ? (Docker Hub, etc.) [O/n]" -ForegroundColor Yellow
$Push = Read-Host ">"
if ($Push -eq "" -or $Push -match "^[OoYy]") {
    Write-Host "Push de $($ImageName):$($Version) ..."
    docker push "$($ImageName):$($Version)"
    
    Write-Host "Push de $($ImageName):latest ..."
    docker push "$($ImageName):latest"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Succès ! L'image est disponible sur le registre." -ForegroundColor Green
        Write-Host "Sur CasaOS, utilisez l'image : $($ImageName):latest" -ForegroundColor Cyan
    }
    else {
        Write-Error "Echec du push. Vérifiez que vous êtes connecté (docker login)."
    }
}
else {
    Write-Host "Push ignoré. L'image est disponible localement."
}
