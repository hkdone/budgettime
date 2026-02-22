
param (
    [string]$Version,
    [string]$Message = "Mise à jour version $Version"
)

if (-not $Version) {
    Write-Error "Veuillez spécifier une version (ex: ./release.ps1 -Version 1.0.1)"
    exit 1
}

Write-Host "=== BudgetTime Release Process v$Version ===" -ForegroundColor Cyan

# 1. Update flutter pubspec.yaml version
Write-Host "1. Updating pubspec.yaml..."
(Get-Content pubspec.yaml) -replace "version: .*", "version: $Version" | Set-Content pubspec.yaml

# 2. Update HA config.yaml version
Write-Host "2. Updating config.yaml..."
(Get-Content budgettime/config.yaml) -replace "version: .*", "version: ""$Version""" | Set-Content budgettime/config.yaml

# 2b. Update Dashboard & Login version
Write-Host "2b. Updating dashboard_page.dart & login_page.dart version..."
(Get-Content lib/features/dashboard/presentation/dashboard_page.dart) -replace "'v\d+\.\d+\.\d+'", "'v$Version'" | Set-Content lib/features/dashboard/presentation/dashboard_page.dart
(Get-Content lib/features/auth/presentation/login_page.dart) -replace "'v\d+\.\d+\.\d+'", "'v$Version'" | Set-Content lib/features/auth/presentation/login_page.dart

# 2c. Update index.html manifest version
Write-Host "2c. Updating index.html manifest version..."
(Get-Content web/index.html) -replace 'manifest.json\?v=[\d.]+', "manifest.json?v=$Version" | Set-Content web/index.html

# 3. Build Flutter Web
Write-Host "3. Building Flutter Web..."
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

# Force HTML renderer to avoid CanvasKit icon issues in some environments
$BootstrapFile = "build\web\flutter_bootstrap.js"
if (Test-Path $BootstrapFile) {
    (Get-Content $BootstrapFile) -replace '"renderer":"canvaskit"', '"renderer":"html"' | Set-Content $BootstrapFile
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed!"
    exit 1
}

# 4. Update budgettime folder assets (for HA/Docker/Synology context)
Write-Host "4. Updating budgettime assets..."

# Public Web
if (Test-Path budgettime/pb_public) { Remove-Item -Recurse -Force budgettime/pb_public }
New-Item -ItemType Directory -Force -Path budgettime/pb_public
Copy-Item -Recurse build\web\* budgettime/pb_public\

# Migrations & Schema
if (Test-Path budgettime/pb_migrations) { Remove-Item -Recurse -Force budgettime/pb_migrations }
if (Test-Path pb_migrations) {
    Copy-Item -Recurse pb_migrations budgettime/
}
Copy-Item pb_schema.json budgettime/
if (Test-Path docker-compose.yml) {
    Copy-Item docker-compose.yml budgettime/
}

# 5. Git Operations
Write-Host "5. Git Operations..."

# Check if git is initialized
if (-not (Test-Path .git)) {
    Write-Host "Initializing Git..."
    git init
    git branch -M main
}

git add .
git commit -m "$Message"
# Check if tag already exists to avoid fatal error
if (git tag -l "v$Version") {
    Write-Host "Tag v$Version already exists, skipping tag creation." -ForegroundColor Yellow
}
else {
    git tag -a "v$Version" -m "Version $Version"
}

Write-Host "=== Git Release Ready locally! ===" -ForegroundColor Green

# 6. Push to GitHub (Master & Main)
$PushGit = Read-Host "Push to GitHub now? [Y/n]"
if ($PushGit -eq "" -or $PushGit -match "^[OoYy]") {
    Write-Host "Pushing to GitHub..." -ForegroundColor Green
    git push origin main --tags --force
    git push origin main:master --force
    Write-Host "GitHub synchronization complete." -ForegroundColor Green
}

# 7. Docker Build & Push
Write-Host "`n=== 7. Docker Deployment (GHCR for CasaOS) ===" -ForegroundColor Cyan
$ImageName = "ghcr.io/hkdone/budgettime"
Write-Host "Prepare to build and push Docker image: $($ImageName):$($Version)"

$PushDocker = Read-Host "Build and Push Docker image now? [Y/n]"
if ($PushDocker -eq "" -or $PushDocker -match "^[OoYy]") {
    Write-Host "Building Docker image (multi-arch ready context)..." -ForegroundColor Green
    
    # Use subexpression syntax for safety, using budgettime/ folder as context
    docker build -t "$($ImageName):$($Version)" -t "$($ImageName):latest" ./budgettime

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker Build Failed!"
        exit 1
    }

    Write-Host "Pushing to GitHub Container Registry..." -ForegroundColor Green
    docker push "$($ImageName):$($Version)"
    docker push "$($ImageName):latest"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker Image Pushed Successfully!" -ForegroundColor Green
    }
    else {
        Write-Error "Docker Push Failed. Please check 'docker login ghcr.io'."
    }
}
else {
    Write-Host "Docker deployment skipped." -ForegroundColor Yellow
}

Write-Host "`n=== Final Update Summary ===" -ForegroundColor Cyan
Write-Host "1. Synology: Copy the content of './budgettime' to your NAS." -ForegroundColor Yellow
Write-Host "2. CasaOS: Image pushed to GHCR. Click 'Update' in CasaOS UI." -ForegroundColor Yellow
Write-Host "3. Home Assistant: Git pushed. Perform a 'git pull' or reinstall in HA." -ForegroundColor Yellow
Write-Host "`n=== Release v$Version Complete! ===" -ForegroundColor Green
