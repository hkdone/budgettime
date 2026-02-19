
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
(Get-Content config.yaml) -replace "version: .*", "version: ""$Version""" | Set-Content config.yaml

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

# 4. Update pb_public
Write-Host "4. Updating pb_public..."
if (Test-Path pb_public) { Remove-Item -Recurse -Force pb_public }
New-Item -ItemType Directory -Force -Path pb_public
Copy-Item -Recurse build\web\* pb_public\

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

Write-Host "=== Git Release Ready! ===" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1. Push to GitHub: git push origin main --tags"

# 6. Docker Build & Push
Write-Host "`n=== 6. Docker Deployment (GHCR) ===" -ForegroundColor Cyan
$ImageName = "ghcr.io/hkdone/budgettime"
Write-Host "Prepare to build and push Docker image: $($ImageName):$($Version)"

$PushDocker = Read-Host "Build and Push Docker image now? [Y/n]"
if ($PushDocker -eq "" -or $PushDocker -match "^[OoYy]") {
    Write-Host "Building Docker image..." -ForegroundColor Green
    
    # Use subexpression syntax for safety
    docker build -t "$($ImageName):$($Version)" -t "$($ImageName):latest" .

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker Build Failed!"
        exit 1
    }

    Write-Host "Pushing to GitHub Container Registry..." -ForegroundColor Green
    docker push "$($ImageName):$($Version)"
    docker push "$($ImageName):latest"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker Image Pushed Successfully!" -ForegroundColor Green
        Write-Host "Update available on CasaOS with tag usage: latest"
    }
    else {
        Write-Error "Docker Push Failed. Please check 'docker login ghcr.io'."
    }
}
else {
    Write-Host "Docker deployment skipped." -ForegroundColor Yellow
}
