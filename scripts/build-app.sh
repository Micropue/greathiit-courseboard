#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export CLANG_MODULE_CACHE_PATH="$ROOT/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"

BUILD_FLAGS=(
  -c release
  --disable-sandbox
  --cache-path "$ROOT/.build/swiftpm-cache"
  -debug-info-format none
)

swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

APP="$ROOT/dist/哈信息课程表.app"
ICON_NAME="CourseBoardIcon"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/CourseBoard" "$APP/Contents/MacOS/CourseBoard"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

APP_VERSION="${APP_VERSION:-1.1.0}"
APP_BUILD="${APP_BUILD:-2}"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $APP_VERSION" \
  "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleVersion $APP_BUILD" \
  "$APP/Contents/Info.plist"

ICONSET="$ROOT/build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ROOT/build"
SWIFT_SCRIPT_FLAGS=(
  -module-cache-path "$ROOT/.build/swift-module-cache"
)
swift "${SWIFT_SCRIPT_FLAGS[@]}" \
  "$ROOT/scripts/make-icon.swift" "$ICONSET"
if ! iconutil -c icns "$ICONSET" \
    -o "$APP/Contents/Resources/$ICON_NAME.icns" 2>/dev/null; then
  swift "${SWIFT_SCRIPT_FLAGS[@]}" "$ROOT/scripts/make-icns.swift" \
    "$ICONSET" "$APP/Contents/Resources/$ICON_NAME.icns"
fi

test -s "$APP/Contents/Resources/$ICON_NAME.icns"
touch "$APP" "$APP/Contents/Resources/$ICON_NAME.icns"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "Built: $APP"
