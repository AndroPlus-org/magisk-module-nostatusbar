#!/bin/bash
# Build overlay APKs for each status bar height into overlays/<N>px/.
# Requires: aapt, zipalign, apksigner, keytool, python3
#   (Debian/Ubuntu: apt install aapt zipalign apksigner android-sdk-platform-23)
#
# AndroidManifest.xml in src/*/ is for reference only. aapt1 cannot compile
# android:isStatic with the old android.jar, so the prebuilt binary manifest
# (AndroidManifest.bin) is injected into the APK instead.
set -e
cd "$(dirname "$0")"

HEIGHTS="${HEIGHTS:-0 1 2 3}"
ANDROID_JAR="${ANDROID_JAR:-/usr/lib/android-sdk/platforms/android-23/android.jar}"
KEYSTORE="${KEYSTORE:-.build/overlay.jks}"
KS_PASS="${KS_PASS:-android}"
BUILD=.build

mkdir -p "$BUILD"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -alias overlay -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=nostatusbar" >/dev/null
fi

build_overlay() {
  local src=$1 name=$2 height=$3 out=$4
  local work="$BUILD/$name-${height}px"
  rm -rf "$work"; mkdir -p "$work"
  cp -r "src/$src/res" "$work/res"
  find "$work/res" -name '*.xml' -exec sed -i "s/@HEIGHT@/${height}px/g" {} +
  local pkg
  pkg=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "src/$src/AndroidManifest.xml")
  printf '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="%s"/>\n' "$pkg" > "$work/AndroidManifest.xml"
  aapt package -f -M "$work/AndroidManifest.xml" -S "$work/res" -I "$ANDROID_JAR" -F "$work/unaligned.apk"
  python3 - "$work/unaligned.apk" "src/$src/AndroidManifest.bin" <<'PY'
import sys, zipfile
apk, manifest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(apk) as z:
    items = [(i, z.read(i.filename)) for i in z.infolist()]
with zipfile.ZipFile(apk, 'w') as z:
    for info, data in items:
        if info.filename == 'AndroidManifest.xml':
            data = open(manifest, 'rb').read()
        # resources.arsc must stay uncompressed
        info.compress_type = zipfile.ZIP_STORED if info.filename == 'resources.arsc' else zipfile.ZIP_DEFLATED
        z.writestr(info, data)
PY
  zipalign -f -p 4 "$work/unaligned.apk" "$work/aligned.apk"
  mkdir -p "$(dirname "$out")"
  apksigner sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --ks-key-alias overlay \
    --out "$out" "$work/aligned.apk"
  rm -f "$out.idsig"
}

for h in $HEIGHTS; do
  build_overlay framework treble-overlay-misc-nostatusbar "$h" "overlays/${h}px/treble-overlay-misc-nostatusbar.apk"
  build_overlay systemui treble-overlay-misc-nostatusbarp "$h" "overlays/${h}px/treble-overlay-misc-nostatusbarp.apk"
  echo "Built overlays/${h}px"
done
