#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PaperEdit"
EXECUTABLE_NAME="PaperEditApp"
BUNDLE_ID="com.paperedit.app"
VERSION="${1:-0.1.0}"
APPCAST_URL="${APPCAST_URL:-https://github.com/kaelinda/PaperEdit/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
BUILD_DIR="$ROOT_DIR/dist"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
MASTER_ICON="$ROOT_DIR/Assets/AppIcon.png"
MASTER_PNG="$BUILD_DIR/AppIcon-1024.png"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"
RELEASE_EXECUTABLE="$ROOT_DIR/.build/release/$EXECUTABLE_NAME"
CLI_EXECUTABLE="$ROOT_DIR/.build/release/paper"
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION-macOS.zip"

if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY is required for Sparkle update verification." >&2
  echo "Generate one with Sparkle's generate_keys tool and pass the public EdDSA key when building." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR" "$ICONSET_DIR"

swift build -c release --package-path "$ROOT_DIR" --product "$EXECUTABLE_NAME"
swift build -c release --package-path "$ROOT_DIR" --product paper

mkdir -p "$ICONSET_DIR"
sips -z 1024 1024 "$MASTER_ICON" --out "$MASTER_PNG" >/dev/null

create_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$MASTER_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

create_icon 16 icon_16x16.png
create_icon 32 icon_16x16@2x.png
create_icon 32 icon_32x32.png
create_icon 64 icon_32x32@2x.png
create_icon 128 icon_128x128.png
create_icon 256 icon_128x128@2x.png
create_icon 256 icon_256x256.png
create_icon 512 icon_256x256@2x.png
create_icon 512 icon_512x512.png
cp "$MASTER_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
cp "$RELEASE_EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$CLI_EXECUTABLE" "$BUILD_DIR/paper"
chmod +x "$BUILD_DIR/paper"

SPARKLE_FRAMEWORK="$ROOT_DIR/ThirdParty/Sparkle.framework"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework was not found at $SPARKLE_FRAMEWORK." >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>PaperEdit Documents</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.data</string>
        <string>public.text</string>
        <string>public.plain-text</string>
        <string>public.source-code</string>
        <string>public.json</string>
        <string>public.xml</string>
        <string>public.yaml</string>
        <string>public.property-list</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>PaperEdit Folders</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.folder</string>
      </array>
    </dict>
  </array>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUFeedURL</key>
  <string>$APPCAST_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
codesign --force --deep --sign - \
  --entitlements "$ROOT_DIR/Sources/PaperEditApp/App/PaperEditApp.entitlements" \
  "$APP_DIR" >/dev/null

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Built app bundle: $APP_DIR"
echo "Built CLI: $BUILD_DIR/paper"
echo "Built archive: $ZIP_PATH"
