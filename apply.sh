#!/usr/bin/env bash
# SakayNa! upgrade for macOS / Linux.
# Usage:  cd <your Flutter project>   then   bash /path/to/SakayNa_upgrade/apply.sh
#         or: bash apply.sh "/path/to/your/project"
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${1:-$PWD}"
cd "$PROJECT"
[ -f pubspec.yaml ] || { echo "pubspec.yaml not found. cd into your Flutter project or pass its path."; exit 1; }
command -v flutter >/dev/null || { echo "Flutter not found in PATH."; exit 1; }
PKG="$(grep '^name:' pubspec.yaml | awk '{print $2}')"
echo "Project: $PROJECT   Package: $PKG"

# 1. Replace app code (old screens are removed on purpose)
rm -rf lib
mkdir -p lib test tools config
cp -R "$HERE/lib/." lib/
rm -f test/*.dart
cp "$HERE"/test/*.dart test/
cp "$HERE"/tools/*.dart tools/
cp "$HERE/config/dev.example.json" config/
sed -i.bak "s#__PKG__#$PKG#g" test/*.dart tools/*.dart && rm -f test/*.bak tools/*.bak

# 2. Dependencies
flutter pub add shared_preferences http

# 3. Keep tokens out of git
touch .gitignore
grep -q 'config/dev.json' .gitignore || printf '\nconfig/dev.json\nconfig/prod.json\n' >> .gitignore

# 4. Rename the app to SakayNa!
[ -f android/app/src/main/AndroidManifest.xml ] && perl -pi -e 's/android:label="[^"]*"/android:label="SakayNa!"/' android/app/src/main/AndroidManifest.xml
[ -f ios/Runner/Info.plist ] && perl -0pi -e 's#(<key>CFBundleDisplayName</key>\s*<string>)[^<]*#${1}SakayNa!#; s#(<key>CFBundleName</key>\s*<string>)[^<]*#${1}SakayNa!#' ios/Runner/Info.plist
[ -f web/index.html ] && perl -0pi -e 's#<title>[^<]*</title>#<title>SakayNa!</title>#; s#(apple-mobile-web-app-title"\s+content=")[^"]*#${1}SakayNa!#' web/index.html
[ -f web/manifest.json ] && perl -pi -e 's#("name":\s*")[^"]*#${1}SakayNa!#; s#("short_name":\s*")[^"]*#${1}SakayNa!#' web/manifest.json

# 5. Android release builds need INTERNET permission for tiles and routing
M=android/app/src/main/AndroidManifest.xml
if [ -f "$M" ] && ! grep -q 'android.permission.INTERNET' "$M"; then
  perl -0pi -e 's#(<manifest[^>]*>)#${1}\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$M"
fi

flutter pub get
flutter test
echo ""
echo "Done. Next:"
echo "  1) cp config/dev.example.json config/dev.json   and paste your Mapbox PUBLIC token (pk...)"
echo "  2) flutter run -d chrome --dart-define-from-file=config/dev.json"
