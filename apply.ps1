# SakayNa! upgrade for Windows (PowerShell).
# Usage:  cd "<your Flutter project>"   then   & "C:\path\to\SakayNa_upgrade\apply.ps1"
#         or: .\apply.ps1 -Project "E:\Codes\ParaPo!\parapo_transpo"
param([string]$Project = (Get-Location).Path)
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
Set-Location -LiteralPath $Project
if (-not (Test-Path "pubspec.yaml")) { throw "pubspec.yaml not found. cd into your Flutter project or pass -Project." }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw "Flutter not found in PATH." }
$pkg = (Select-String -Path "pubspec.yaml" -Pattern '^name:\s*(\S+)').Matches[0].Groups[1].Value
Write-Host "Project: $Project   Package: $pkg"

# 1. Replace app code (old screens are removed on purpose)
if (Test-Path "lib") { Remove-Item "lib" -Recurse -Force }
New-Item -ItemType Directory -Force -Path "lib","test","tools","config" | Out-Null
Copy-Item "$here\lib\*" "lib" -Recurse -Force
Remove-Item "test\*.dart" -Force -ErrorAction SilentlyContinue
Copy-Item "$here\test\*.dart" "test" -Force
Copy-Item "$here\tools\*.dart" "tools" -Force
Copy-Item "$here\config\dev.example.json" "config" -Force
foreach ($f in Get-ChildItem -Path "test","tools" -Filter *.dart) {
  $t = Get-Content -LiteralPath $f.FullName -Raw
  Set-Content -LiteralPath $f.FullName -Value ($t -replace '__PKG__', $pkg) -NoNewline
}

# 2. Dependencies
flutter pub add shared_preferences http

# 3. Keep tokens out of git
if (-not (Test-Path ".gitignore")) { New-Item ".gitignore" -ItemType File | Out-Null }
if (-not (Select-String -Path ".gitignore" -Pattern 'config/dev.json' -Quiet)) {
  Add-Content ".gitignore" "`nconfig/dev.json`nconfig/prod.json"
}

# 4. Rename the app to SakayNa!
function Edit-File($path, $pairs) {
  if (Test-Path $path) {
    $t = Get-Content -LiteralPath $path -Raw
    foreach ($p in $pairs) { $t = [regex]::Replace($t, $p[0], $p[1]) }
    Set-Content -LiteralPath $path -Value $t -NoNewline
  }
}
Edit-File "android\app\src\main\AndroidManifest.xml" @(,@('android:label="[^"]*"', 'android:label="SakayNa!"'))
Edit-File "ios\Runner\Info.plist" @(
  @('(<key>CFBundleDisplayName</key>\s*<string>)[^<]*', '${1}SakayNa!'),
  @('(<key>CFBundleName</key>\s*<string>)[^<]*', '${1}SakayNa!'))
Edit-File "web\index.html" @(
  @('<title>[^<]*</title>', '<title>SakayNa!</title>'),
  @('(apple-mobile-web-app-title"\s+content=")[^"]*', '${1}SakayNa!'))
Edit-File "web\manifest.json" @(
  @('("name":\s*")[^"]*', '${1}SakayNa!'),
  @('("short_name":\s*")[^"]*', '${1}SakayNa!'))

# 5. Android release builds need INTERNET permission
$m = "android\app\src\main\AndroidManifest.xml"
if ((Test-Path $m) -and -not (Select-String -Path $m -Pattern 'android.permission.INTERNET' -Quiet)) {
  Edit-File $m @(,@('(<manifest[^>]*>)', '${1}' + "`n    " + '<uses-permission android:name="android.permission.INTERNET"/>'))
}

flutter pub get
flutter test
Write-Host ""
Write-Host "Done. Next:"
Write-Host "  1) Copy config\dev.example.json to config\dev.json and paste your Mapbox PUBLIC token (pk...)"
Write-Host "  2) flutter run -d chrome --dart-define-from-file=config/dev.json"
