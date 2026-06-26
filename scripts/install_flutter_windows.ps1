# Installe Flutter SDK (stable) dans C:\src\flutter et l'ajoute au PATH utilisateur.
# À lancer une seule fois :  powershell -ExecutionPolicy Bypass -File .\scripts\install_flutter_windows.ps1

$ErrorActionPreference = "Stop"
$FlutterRoot = "C:\src\flutter"
$ZipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.4-stable.zip"
$ZipFile = Join-Path $PSScriptRoot ".cache\flutter_windows_stable.zip"
$CacheDir = Join-Path $PSScriptRoot ".cache"
if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }

Write-Host "=== Installation Flutter pour BudgetTime ===" -ForegroundColor Cyan

if (Test-Path "$FlutterRoot\bin\flutter.bat") {
    Write-Host "Flutter semble déjà installé dans $FlutterRoot" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Force -Path "C:\src" | Out-Null

    if (-not (Test-Path $ZipFile) -or (Get-Item $ZipFile).Length -lt 900MB) {
        if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
        Write-Host "Téléchargement Flutter stable (~1 Go, patientez)..." -ForegroundColor Green
        curl.exe -L --retry 3 --retry-delay 5 -o $ZipFile $ZipUrl
        if ($LASTEXITCODE -ne 0) { throw "Échec du téléchargement Flutter (curl)" }
    }

    Write-Host "Extraction vers $FlutterRoot ..." -ForegroundColor Green
    if (Test-Path $FlutterRoot) { Remove-Item -Recurse -Force $FlutterRoot }
    Expand-Archive -Path $ZipFile -DestinationPath "C:\src" -Force
}

$binPath = "$FlutterRoot\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binPath*") {
    Write-Host "Ajout de Flutter au PATH utilisateur..." -ForegroundColor Green
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binPath", "User")
}

$env:Path = "$binPath;" + $env:Path

Write-Host "Configuration Web..." -ForegroundColor Green
& "$FlutterRoot\bin\flutter.bat" config --enable-web
& "$FlutterRoot\bin\flutter.bat" doctor

Write-Host ""
Write-Host "=== Terminé ===" -ForegroundColor Green
Write-Host "Fermez et rouvrez PowerShell, puis : flutter --version"
Write-Host "Dans le projet : flutter pub get"
