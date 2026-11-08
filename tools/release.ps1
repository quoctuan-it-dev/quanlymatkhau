# Lenh phat hanh ban moi cua app "Quan ly mat khau".
# Cach chay (trong thu muc project):
#   powershell -ExecutionPolicy Bypass -File tools\release.ps1 -Notes "Noi dung thay doi"
param(
    [string]$Notes = ""
)
$ErrorActionPreference = "Stop"
$Repo = "quoctuan-it-dev/quanlymatkhau"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

# Doc so phien ban tu pubspec.yaml (vi du: version: 1.0.1+2)
$line = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)' | Select-Object -First 1
if (-not $line) { throw "Khong doc duoc dong 'version:' trong pubspec.yaml" }
$VersionName = $line.Matches[0].Groups[1].Value
$VersionCode = [int]$line.Matches[0].Groups[2].Value
$Tag = "v$VersionName"
$ApkName = "quanlymatkhau-$VersionName.apk"

Write-Host "== Build ban $VersionName (versionCode $VersionCode) ==" -ForegroundColor Cyan
flutter build apk --release --obfuscate --split-debug-info=build/symbols/$VersionName
if ($LASTEXITCODE -ne 0) { throw "Build that bai" }

$Dist = Join-Path $Root "dist\$Tag"
New-Item -ItemType Directory -Force $Dist | Out-Null
$ApkPath = Join-Path $Dist $ApkName
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $ApkPath -Force

$Sha = (Get-FileHash $ApkPath -Algorithm SHA256).Hash.ToLower()

$info = [ordered]@{
    versionCode = $VersionCode
    versionName = $VersionName
    apkUrl      = "https://github.com/$Repo/releases/download/$Tag/$ApkName"
    sha256      = $Sha
    notes       = $Notes
}
$json = $info | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $Dist "version.json"), $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "XONG! 2 file can dua len GitHub nam trong: $Dist" -ForegroundColor Green
Write-Host "  - $ApkName"
Write-Host "  - version.json"
Write-Host "SHA-256: $Sha"
Write-Host ""
Write-Host "Tiep theo: GitHub > Releases > Draft a new release > tag $Tag > keo tha 2 file > Publish release."
Start-Process explorer.exe $Dist