#!/bin/bash
# Build "Caffeine Cat.app" into ./build. Use --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Caffeine Cat.app"
ICONSET="build/AppIcon.iconset"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"

swiftc -O -parse-as-library \
    -target "$(uname -m)-apple-macos14.0" \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/CaffeineCat"

cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/frames "$APP/Contents/Resources/frames"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

for size in 16 32 128 256 512; do
    sips -z $size $size Resources/icon_1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double Resources/icon_1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x CaffeineCat 2>/dev/null || true
    rm -rf "/Applications/Caffeine Cat.app"
    cp -R "$APP" /Applications/
    echo "Installed /Applications/Caffeine Cat.app"
fi
