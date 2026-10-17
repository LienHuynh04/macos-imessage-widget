# iMessage Bubble

Bong bóng chat mini **luôn nổi trên màn hình** macOS — AppKit thuần túy
(không SwiftUI), không đăng nhập, không mạng, dữ liệu giả lập trong RAM.

## Tính năng

- **Bong bóng tròn xanh 68pt** (`#0084FF` + icon `message.fill` trắng), luôn nổi
  trên cửa sổ thường (`.floating`), bám mọi Space kể cả fullscreen, không ẩn
  khi app khác active, không icon Dock.
- **Kéo thả tự do** khắp màn hình; **nhớ vị trí** sau khi thoát/mở lại
  (lưu trong UserDefaults).
- **Bấm vào bubble** → mở/đóng cửa sổ chat tối giản (AppKit thuần):
  log tin nhắn mẫu, ô nhập + nút Gửi (Enter cũng gửi), có trả lời tự động.
- **Chuột phải vào bubble** → menu: Mở/đóng chat, Thoát.
- Thoát: menu chuột phải → Thoát, hoặc Cmd+Q.

## Yêu cầu hệ thống

- macOS 15 trở lên (chạy tốt trên macOS Tahoe 26).
- Xcode đầy đủ (khuyên dùng) hoặc Xcode Command Line Tools
  (`xcode-select --install`).
- Không cần quyền hệ thống nào (không Accessibility, không Full Disk Access).

## Cách build & chạy

```bash
cd imessage-bubble
chmod +x build.sh   # chỉ cần lần đầu (nếu mất bit thực thi)
./build.sh
```

`build.sh` biên dịch `Sources/main.swift` (AppKit thuần, 1 file duy nhất),
đóng gói thành `dist/iMessage Bubble.app`, ký ad-hoc và tự mở app.

Mở tay: `open "dist/iMessage Bubble.app"`. Kéo vào `/Applications` để dùng lâu dài.

## Giới hạn hiện tại

- Cửa sổ chat là bản tối giản demo (log text + ô nhập), chưa phải full
  Messenger UI như project `imessage-mini`.
- Tin nhắn mẫu + trả lời tự động, chỉ sống trong RAM (tắt app là mất).
- Chưa tự khởi động cùng macOS (có thể thêm bằng SMAppService sau).
- Chưa có badge số tin chưa đọc trên bubble.

## Quyền riêng tư

- Không có network request nào trong code.
- Không thu thập dữ liệu, không đọc Messages/iMessage/Messenger.
- `build.sh` không tắt Gatekeeper, không sửa bảo mật macOS.
