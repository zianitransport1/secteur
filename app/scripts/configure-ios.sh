#!/usr/bin/env bash
# Réglages iOS appliqués après « cap add ios » (macOS uniquement) :
# permissions de localisation, GPS en arrière-plan, nom affiché, icône.
set -euo pipefail
cd "$(dirname "$0")/.."
PLIST=ios/App/App/Info.plist
PB=/usr/libexec/PlistBuddy

set_key() { # set_key <clé> <type> <valeur>
  $PB -c "Delete :$1" "$PLIST" 2>/dev/null || true
  $PB -c "Add :$1 $2 $3" "$PLIST"
}

set_key CFBundleDisplayName string "Ma tournée"
set_key NSLocationWhenInUseUsageDescription string "Ta position sert à tracer ta tournée sur la carte et à indiquer les rues déjà faites."
set_key NSLocationAlwaysAndWhenInUseUsageDescription string "Ta position continue d'être suivie pendant la tournée, même écran verrouillé, pour que les rues faites soient bien comptées."
set_key ITSAppUsesNonExemptEncryption bool false
$PB -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
$PB -c "Add :UIBackgroundModes array" "$PLIST"
$PB -c "Add :UIBackgroundModes:0 string location" "$PLIST"

# Icône 1024x1024 (sans transparence, exigé par Apple)
ICONSET=ios/App/App/Assets.xcassets/AppIcon.appiconset
rm -f "$ICONSET"/*.png
cp assets/icon-1024.png "$ICONSET/AppIcon-1024.png"
cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "Projet iOS configuré"
