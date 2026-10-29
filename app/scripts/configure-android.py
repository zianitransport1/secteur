#!/usr/bin/env python3
"""Réglages Android appliqués après « cap add android » :
permissions de localisation, notification du suivi, icône, numéro de version."""
import os, re, sys, shutil
from PIL import Image

os.chdir(os.path.join(os.path.dirname(__file__), '..'))
version = sys.argv[1] if len(sys.argv) > 1 else '1.0'
build = sys.argv[2] if len(sys.argv) > 2 else '1'

# 1. Permissions
m = 'android/app/src/main/AndroidManifest.xml'
s = open(m).read()
perms = ['ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION', 'POST_NOTIFICATIONS']
add = ''.join('    <uses-permission android:name="android.permission.%s" />\n' % p for p in perms if p not in s)
add += '    <uses-feature android:name="android.hardware.location.gps" android:required="false" />\n'
s = s.replace('    <uses-permission android:name="android.permission.INTERNET" />\n',
              '    <uses-permission android:name="android.permission.INTERNET" />\n' + add, 1)
assert 'ACCESS_FINE_LOCATION' in s, 'manifest non modifié'
open(m, 'w').write(s)

# 2. Textes de la notification de suivi (obligatoire sur Android pour le GPS en arrière-plan)
v = 'android/app/src/main/res/values/strings.xml'
s = open(v).read()
if 'capacitor_background_geolocation_notification_channel_name' not in s:
    s = s.replace('</resources>', '    <string name="capacitor_background_geolocation_notification_channel_name">Suivi de tournée</string>\n'
                                  '    <string name="capacitor_background_geolocation_notification_color">#16a34a</string>\n</resources>')
open(v, 'w').write(s)

# 3. Icône (logo Ziani Transport sur fond blanc)
src = Image.open('assets/icon-1024.png').convert('RGB')
res = 'android/app/src/main/res'
for d, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    out = os.path.join(res, 'mipmap-' + d)
    os.makedirs(out, exist_ok=True)
    img = src.resize((px, px), Image.LANCZOS)
    for n in ('ic_launcher.png', 'ic_launcher_round.png'):
        img.save(os.path.join(out, n))
    fg = Image.new('RGB', (px * 108 // 48,) * 2, (255, 255, 255))
    inner = src.resize((px * 72 // 48,) * 2, Image.LANCZOS)
    fg.paste(inner, ((fg.width - inner.width) // 2,) * 2)
    fg.save(os.path.join(out, 'ic_launcher_foreground.png'))
shutil.rmtree(os.path.join(res, 'mipmap-anydpi-v26'), ignore_errors=True)   # pas d'icône adaptative par défaut

# 4. Version
g = 'android/app/build.gradle'
s = open(g).read()
s = re.sub(r'versionCode \d+', 'versionCode ' + build, s)
s = re.sub(r'versionName "[^"]*"', 'versionName "%s"' % version, s)
open(g, 'w').write(s)
print('Projet Android configuré', version, build)
