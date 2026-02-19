
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
git tag -a "v$Version" -m "Version $Version"

Write-Host "=== Release Ready! ===" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "1. Push to GitHub: git push origin main --tags"
Write-Host "2. Home Assistant will detect the new version via config.yaml"
