#!/bin/bash
# 把 DeskNote.swift 打包成双击可启动的 工作桌签.app
# 用法：bash build_app.sh
set -e

SRC="$HOME/.desknote/DeskNote.swift"
FONT="$HOME/Library/Fonts/fusion-pixel-12px-proportional-zh_hans.ttf"
APP="$HOME/Applications/工作桌签.app"
BUNDLE_ID="com.lemonpp.desknote"

echo "==> 编译"
swiftc -O "$SRC" -o /tmp/desknote_bin

echo "==> 建立 .app 结构：$APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

mv /tmp/desknote_bin "$APP/Contents/MacOS/desknote"
chmod +x "$APP/Contents/MacOS/desknote"

# 把字体打进包里，.app 自带、不依赖外部安装
if [ -f "$FONT" ]; then
  cp "$FONT" "$APP/Contents/Resources/"
  echo "==> 已内置字体"
else
  echo "==> 警告：没找到字体，跳过内置（应用会回退系统字体）"
fi

echo "==> 写 Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>工作桌签</string>
    <key>CFBundleDisplayName</key>       <string>工作桌签</string>
    <key>CFBundleExecutable</key>        <string>desknote</string>
    <key>CFBundleIdentifier</key>        <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>           <string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

# 去掉隔离属性，避免首次打开被拦
xattr -cr "$APP" 2>/dev/null || true

echo "==> 完成：$APP"
