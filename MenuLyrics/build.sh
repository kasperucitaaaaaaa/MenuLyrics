#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/MenuLyrics.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT
APP="$BUILD_DIR/MenuLyrics.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -module-cache-path "${TMPDIR:-/tmp}/MenuLyricsModuleCache" -swift-version 5 -O -framework AppKit Sources/Lyrics.swift Sources/Localization.swift Sources/main.swift -o "$APP/Contents/MacOS/MenuLyrics"
mkdir -p "$APP/Contents/Resources"
xcrun swiftc -module-cache-path "${TMPDIR:-/tmp}/MenuLyricsModuleCache" -framework AppKit Tools/GenerateIcon.swift -o "$BUILD_DIR/generate-icon"
"$BUILD_DIR/generate-icon" "$BUILD_DIR/MenuLyrics.iconset" "$APP/Contents/Resources/AppIcon.icns"
cp "$BUILD_DIR/MenuLyrics.iconset/icon_512x512@2x.png" "$PWD/Assets/AppIcon.png"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MenuLyrics</string>
<key>CFBundleIdentifier</key><string>local.menulyrics.app</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>1.2.2</string>
<key>CFBundleName</key><string>MenuLyrics</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.2</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSAppleEventsUsageDescription</key><string>读取 Apple Music 当前歌曲和播放进度，以同步显示菜单栏歌词。</string>
</dict></plist>
PLIST
mkdir -p "$APP/Contents/Resources/en.lproj" "$APP/Contents/Resources/zh-Hans.lproj"
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'EN'
"NSAppleEventsUsageDescription" = "Read the current Apple Music song and playback position to synchronize menu bar lyrics.";
EN
cat > "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings" <<'ZH'
"NSAppleEventsUsageDescription" = "读取 Apple Music 当前歌曲和播放进度，以同步显示菜单栏歌词。";
ZH
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/MenuLyrics.zip"
print "已生成：$PWD/MenuLyrics.zip"
