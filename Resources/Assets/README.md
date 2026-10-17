# Resources/Assets — Tài nguyên ảnh cục bộ

Mọi ảnh trong app đều đọc từ thư mục này. **Không tải ảnh từ Internet.**

## Quy ước đặt tên

| Tiền tố              | Dùng cho                  | Ví dụ              |
|----------------------|---------------------------|--------------------|
| `chat-background.*`  | Ảnh nền khu vực hội thoại | `chat-background.png` |
| `avatar-<tên>.*`     | Avatar cá nhân/nhóm       | `avatar-an.png`    |
| `sticker-<tên>.*`    | Sticker trong tin nhắn    | `sticker-chao.png` |
| `photo-<tên>.*`      | Ảnh trong tin nhắn        | `photo-homestay.png` |

Định dạng hỗ trợ: `png`, `jpg`, `jpeg`, `heic`, `webp`.
`build.sh` tự động copy các file ảnh vào app bundle khi build.

## Cách dùng

- **Ảnh nền hội thoại:** đặt `backgroundImageName` trong `MockData.chatTheme`
  (vd `"chat-background"` — không cần ghi extension).
- **Avatar:** `avatarImageName` trong `ChatHeaderConfig`,
  hoặc `senderAvatarName` trong từng `MessageModel`.
- **Sticker / ảnh trong tin nhắn:** `MessageContent.sticker(imageName:...)`
  hoặc `.image(imageName:...)`. Nếu không tìm thấy file, app tự dùng
  placeholder (emoji cho sticker, khung gradient cho ảnh).

## Lưu ý bản quyền

Chỉ dùng ảnh bạn có quyền sử dụng: ảnh tự chụp, ảnh do bạn vẽ/tạo,
hoặc ảnh miễn phí bản quyền rõ ràng. Không nhúng ảnh cá nhân của người khác
khi chưa được họ cho phép.
