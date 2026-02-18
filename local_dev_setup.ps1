Write-Host "=== BudgetTime Local Dev Setup ==="

# 1. Download PocketBase (Windows AMD64)
if (-not (Test-Path "pocketbase.exe")) {
    Write-Host "Downloading PocketBase..."
    Invoke-WebRequest -Uri "https://github.com/pocketbase/pocketbase/releases/download/v0.22.3/pocketbase_0.22.3_windows_amd64.zip" -OutFile "pb.zip"
    Expand-Archive -Force pb.zip -DestinationPath .
    Remove-Item pb.zip
}
else {
    Write-Host "PocketBase already present."
}

# 2. Build Flutter Web
Write-Host "Building Flutter Web..."
flutter build web --release

# 3. Deploy to pb_public
Write-Host "Deploying to pb_public..."
if (Test-Path "pb_public") { Remove-Item -Recurse -Force "pb_public" }
Copy-Item -Recurse "build\web" "pb_public"

# 4. Start Server
Write-Host "Starting PocketBase on http://127.0.0.1:8090"
Write-Host "Admin UI: http://127.0.0.1:8090/_/"
./pocketbase serve --http="127.0.0.1:8090"
