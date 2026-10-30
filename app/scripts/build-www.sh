#!/usr/bin/env bash
# Prépare le dossier www/ embarqué dans l'app à partir de la page web du dépôt.
# Les bibliothèques (Leaflet, QR code) sont copiées dans l'app pour qu'elle démarre même avec un réseau faible.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=..
rm -rf www && mkdir -p www/vendor
cp "$ROOT/index.html" "$ROOT/icon-192.png" "$ROOT/icon-512.png" "$ROOT/manifest.webmanifest" "$ROOT/logo.png" "$ROOT/logo-blanc.png" www/

CDN=https://cdnjs.cloudflare.com/ajax/libs
curl -fsSL "$CDN/leaflet/1.9.4/leaflet.min.css" -o www/vendor/leaflet.min.css
curl -fsSL "$CDN/leaflet/1.9.4/leaflet.min.js"  -o www/vendor/leaflet.min.js
curl -fsSL "$CDN/qrcode-generator/1.4.4/qrcode.min.js" -o www/vendor/qrcode.min.js

# Remplace les liens CDN par les copies locales (sed compatible macOS et Linux)
for f in leaflet/1.9.4/leaflet.min.css leaflet/1.9.4/leaflet.min.js qrcode-generator/1.4.4/qrcode.min.js; do
  sed -i.bak "s#$CDN/$f#vendor/$(basename "$f")#g" www/index.html
done
rm -f www/index.html.bak

if grep -q "cdnjs.cloudflare.com" www/index.html; then
  echo "Erreur : un lien CDN n'a pas été remplacé" >&2; exit 1
fi
echo "www/ prêt"
