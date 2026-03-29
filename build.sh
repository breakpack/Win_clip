#!/bin/bash
set -e

SRCDIR="ClipBoard"
BUILDDIR="build"
APPNAME="ClipBoard"
APPBUNDLE="$BUILDDIR/$APPNAME.app"
MODE="${1:-debug}"  # debug 또는 release

SOURCES=(
    "$SRCDIR/main.swift"
    "$SRCDIR/AppDelegate.swift"
    "$SRCDIR/ClipboardItem.swift"
    "$SRCDIR/ClipboardMonitor.swift"
    "$SRCDIR/ClipboardPanel.swift"
    "$SRCDIR/ShortcutRecorder.swift"
    "$SRCDIR/SettingsManager.swift"
    "$SRCDIR/SettingsWindowController.swift"
)

rm -rf "$BUILDDIR"
mkdir -p "$APPBUNDLE/Contents/MacOS"
mkdir -p "$APPBUNDLE/Contents/Resources"

SDK=$(xcrun --show-sdk-path)

if [ "$MODE" = "release" ]; then
    echo "🔨 릴리즈 빌드 (Universal Binary)..."

    # arm64
    swiftc \
        -O -whole-module-optimization \
        -swift-version 5 \
        -target arm64-apple-macosx13.0 \
        -sdk "$SDK" \
        -framework Cocoa \
        -framework Carbon \
        -o "$BUILDDIR/${APPNAME}_arm64" \
        "${SOURCES[@]}"

    # x86_64
    swiftc \
        -O -whole-module-optimization \
        -swift-version 5 \
        -target x86_64-apple-macosx13.0 \
        -sdk "$SDK" \
        -framework Cocoa \
        -framework Carbon \
        -o "$BUILDDIR/${APPNAME}_x86" \
        "${SOURCES[@]}"

    # Universal Binary
    lipo -create \
        "$BUILDDIR/${APPNAME}_arm64" \
        "$BUILDDIR/${APPNAME}_x86" \
        -output "$APPBUNDLE/Contents/MacOS/$APPNAME"

    rm "$BUILDDIR/${APPNAME}_arm64" "$BUILDDIR/${APPNAME}_x86"

    # 바이너리 strip
    strip -x "$APPBUNDLE/Contents/MacOS/$APPNAME"

    echo "  ✅ Universal Binary 생성 완료"
else
    echo "🔨 디버그 빌드..."
    swiftc \
        -swift-version 5 \
        -target arm64-apple-macosx13.0 \
        -sdk "$SDK" \
        -framework Cocoa \
        -framework Carbon \
        -o "$APPBUNDLE/Contents/MacOS/$APPNAME" \
        "${SOURCES[@]}"
fi

# Info.plist
cp "$SRCDIR/Info.plist" "$APPBUNDLE/Contents/"

# 아이콘
if [ -f "$SRCDIR/AppIcon.icns" ]; then
    cp "$SRCDIR/AppIcon.icns" "$APPBUNDLE/Contents/Resources/"
    echo "  ✅ 아이콘 복사 완료"
fi

# Entitlements
cp "$SRCDIR/ClipBoard.entitlements" "$APPBUNDLE/Contents/"

# Ad-hoc 코드 서명
codesign --force --deep --sign - "$APPBUNDLE" 2>/dev/null && echo "  ✅ Ad-hoc 서명 완료" || echo "  ⚠️  서명 스킵"

# 바이너리 정보
echo ""
file "$APPBUNDLE/Contents/MacOS/$APPNAME"

if [ "$MODE" = "release" ]; then
    # DMG 생성
    echo ""
    echo "📦 DMG 생성 중..."
    DMGDIR="$BUILDDIR/dmg"
    mkdir -p "$DMGDIR"
    cp -R "$APPBUNDLE" "$DMGDIR/"
    ln -s /Applications "$DMGDIR/Applications"

    hdiutil create \
        -volname "ClipBoard" \
        -srcfolder "$DMGDIR" \
        -ov -format UDZO \
        "$BUILDDIR/ClipBoard-1.0.0.dmg" \
        -quiet

    rm -rf "$DMGDIR"
    echo "  ✅ DMG 생성 완료: $BUILDDIR/ClipBoard-1.0.0.dmg"
fi

echo ""
echo "✅ 빌드 완료: $APPBUNDLE"
echo "실행: open $APPBUNDLE"
