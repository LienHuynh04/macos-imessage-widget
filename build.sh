#!/bin/bash
#
# Build & đóng gói "Messenger Bubble" (bản DIY — tự học, tự sửa).
#
# App bọc Messenger web: cần MẠNG (mở messenger.com) và bạn phải TỰ
# đăng nhập Facebook 1 lần ngay trong app. Không thư viện bên thứ ba.
#
# Yêu cầu (chạy trên Mac):
#   - macOS 15 trở lên
#   - Xcode đầy đủ (khuyên dùng) hoặc Xcode Command Line Tools:
#         xcode-select --install
#
# Cách dùng:
#   1. chmod +x build.sh        (chỉ cần làm 1 lần)
#   2. ./build.sh               (mỗi lần sửa code xong chạy lại)

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Messenger Bubble"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

export MACOSX_DEPLOYMENT_TARGET="15.0"

# --- 1. Chọn compiler ---
if command -v xcrun >/dev/null 2>&1; then
    echo "→ Dùng Xcode toolchain (xcrun --sdk macosx swiftc)"
    SWIFTC="xcrun --sdk macosx swiftc"
elif command -v swiftc >/dev/null 2>&1; then
    echo "→ Dùng swiftc (Command Line Tools)"
    SWIFTC="swiftc"
else
    echo "✗ Không tìm thấy Swift compiler." >&2
    echo "  Cài Xcode Command Line Tools rồi chạy lại:" >&2
    echo "      xcode-select --install" >&2
    exit 1
fi

# --- 2. Dọn dẹp ---
echo "→ Dừng bản đang chạy (nếu có)..."
pkill -x "$APP_NAME" 2>/dev/null || true

echo "→ Dọn $DIST_DIR cũ..."
rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# --- 3. Info.plist ---
echo "→ Copy Info.plist..."
cp Resources/Info.plist "$CONTENTS/Info.plist"

# --- 4. Biên dịch (AppKit + WebKit, 1 file duy nhất) ---
echo "→ Biên dịch Swift..."
# shellcheck disable=SC2086
$SWIFTC -O \
    -o "$MACOS_DIR/$APP_NAME" \
    Sources/main.swift \
    -framework AppKit \
    -framework WebKit

# --- 5. Ký ad-hoc (chuẩn cho app build local) ---
if command -v codesign >/dev/null 2>&1; then
    echo "→ Ký ad-hoc..."
    codesign --sign - --force "$APP_BUNDLE" 2>/dev/null || \
        echo "  (bỏ qua ký: tiếp tục không cần chữ ký)"
fi

echo "✓ Xong: $APP_BUNDLE"
echo "→ Mở ứng dụng..."
open "$APP_BUNDLE"
