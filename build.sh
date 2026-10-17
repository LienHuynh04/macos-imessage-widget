#!/bin/bash
#
# Build & đóng gói "iMessage Mini" cho macOS.
#
# Yêu cầu (chạy trên Mac):
#   - macOS 15 trở lên (mục tiêu kiểm chứng: macOS Tahoe 26)
#   - Xcode đầy đủ (khuyên dùng) hoặc Xcode Command Line Tools
#     Cài CLT bằng:  xcode-select --install
#
# Không cần thư viện bên thứ ba, không cần đăng nhập, không cần mạng.
# Không tắt Gatekeeper, không sửa bảo mật macOS, không tự cấp quyền hệ thống.

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="iMessage Mini"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

# Build cho macOS 15+ (chạy tốt trên Tahoe 26).
export MACOSX_DEPLOYMENT_TARGET="15.0"

# --- 1. Chọn compiler: ưu tiên Xcode toolchain, fallback Command Line Tools ---
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

# --- 4. Tài nguyên ảnh ---
echo "→ Copy tài nguyên ảnh..."
find Resources -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' -o -iname '*.webp' \) \
    -exec cp {} "$RES_DIR/" \;

# --- 5. Biên dịch ---
echo "→ Biên dịch Swift..."
SWIFT_FILES=( $(find Sources -name '*.swift' | sort) )
# shellcheck disable=SC2086
$SWIFTC -O \
    -o "$MACOS_DIR/$APP_NAME" \
    "${SWIFT_FILES[@]}" \
    -framework AppKit \
    -framework SwiftUI

# --- 6. Ký ad-hoc (chuẩn cho app build local; KHÔNG thay đổi bảo mật hệ thống) ---
if command -v codesign >/dev/null 2>&1; then
    echo "→ Ký ad-hoc..."
    codesign --sign - --force "$APP_BUNDLE" 2>/dev/null || \
        echo "  (bỏ qua ký: tiếp tục không cần chữ ký)"
fi

echo "✓ Xong: $APP_BUNDLE"
echo "→ Mở ứng dụng..."
open "$APP_BUNDLE"
