# iMessage Mini

Ứng dụng cửa sổ chat nổi cho macOS — mô phỏng giao diện Messenger, chạy độc lập,
**không đăng nhập, không mạng, không đọc dữ liệu từ bất kỳ đâu**.

## Yêu cầu hệ thống

- macOS 15 (Sequoia) trở lên — đã hướng tới **macOS Tahoe 26**.
- Xcode đầy đủ (khuyên dùng) **hoặc** Xcode Command Line Tools.
  Cài CLT bằng lệnh: `xcode-select --install`
- Chip Apple Silicon hoặc Intel (build theo kiến trúc của máy build).
- Không cần tài khoản, không cần mạng, không cần quyền hệ thống nào
  (không Accessibility, không Full Disk Access).

## Cách build

```bash
cd ~/workspace/imessage-mini
./build.sh
```

`build.sh` sẽ tự động:

1. Chọn compiler: ưu tiên `xcrun --sdk macosx swiftc` (Xcode), nếu không có
   thì dùng `swiftc` (Command Line Tools). Thiếu cả hai → báo lỗi rõ ràng.
2. Dừng bản đang chạy (nếu có), dọn thư mục `dist/`.
3. Biên dịch toàn bộ `Sources/**/*.swift` với `-framework AppKit -framework SwiftUI`,
   target macOS 15+ (chạy tốt trên Tahoe 26).
4. Đóng gói thành **`dist/iMessage Mini.app`** (kèm `Info.plist` và ảnh trong
   `Resources/Assets/`).
5. Ký ad-hoc (`codesign -s -`) — chuẩn cho app build local, **không** tắt
   Gatekeeper, **không** sửa bảo mật macOS.
6. Tự mở app bằng `open`.

> Ghi chú: build **bắt buộc chạy trên Mac**. Máy Linux/Windows không có
> macOS SDK nên không biên dịch được AppKit/SwiftUI.

## Cách chạy

- Sau khi build: app tự mở. Hoặc mở tay:
  ```bash
  open "dist/iMessage Mini.app"
  ```
- Có thể kéo `dist/iMessage Mini.app` vào `/Applications` để dùng lâu dài.

## Cách thoát ứng dụng

- Bấm nút **×** đỏ trên header, hoặc
- Nhấn **Cmd+Q** khi đang ở app (menu Quit).

App là single-panel utility: đóng cửa sổ duy nhất thì app thoát hẳn,
không chạy nền.

## Tính năng đã hoạt động

- **Cửa sổ nổi**: borderless 660×870 (tối thiểu 480×600), bo góc 20pt, bóng đổ,
  nền trong suốt ngoài vùng giao diện; luôn nổi trên cửa sổ thường (`.floating`),
  bám theo mọi Space, hiện được trên Space fullscreen; không cướp focus app khác;
  không icon Dock.
- **Kéo cửa sổ** bằng vùng header (trừ các nút bấm).
- **Header chat**: nền teal #064B63 cao 94pt, avatar tròn 52pt, tên nhóm
  "Hội bạn thân 🧑🏻‍🎨", icon tắt thông báo, 4 nút (gọi thoại, gọi video,
  thu nhỏ, đóng) — nút gọi chỉ là giao diện.
- **Thu nhỏ thành bong bóng**: nút − → panel fade ra, bong bóng tròn xanh 68pt
  hiện ở góc dưới-phải vị trí cũ; kéo bong bóng khắp Desktop; bấm bong bóng
  mở lại cửa sổ đúng vị trí cũ; không tạo trùng lặp khi bấm nhiều lần.
- **Hội thoại**: tin nhắn nhận trái (#303A3D), gửi phải (#0084FF), bo 22pt;
  gom nhóm theo người gửi (tên 1 lần, avatar 28pt ở cuối nhóm); giờ, trạng thái
  Đã gửi/Đã xem, emoji reaction; sticker và ảnh là message riêng;
  tự cuộn tới cuối; ảnh nền cục bộ + lớp phủ teal; ảnh trong tin nhắn giữ tỷ lệ.
- **Soạn tin**: ô nhập "Aa" (Enter gửi, Shift+Enter xuống dòng), nút gửi hiện
  khi có nội dung, nút emoji chèn emoji, nút ảnh mở NSOpenPanel chọn ảnh từ máy
  (file được copy vào Application Support, file gốc nguyên vẹn).
- **Đổi ảnh nền/avatar**: thả file vào `Resources/Assets/` theo quy ước trong
  `Resources/Assets/README.md`, sửa `MockData` rồi build lại.

## Tính năng demo (ghi rõ, không giả vờ có dịch vụ)

- Nút **GIF** và nút **+**: hiện thẻ giải thích "bản demo — chưa kết nối dịch vụ".
- Nút **sticker**: mở bảng sticker emoji, bấm là gửi ngay (hoạt động thật, cục bộ).
- Nút **gọi thoại / gọi video** trên header: chỉ là giao diện, không gọi.

## Quyền riêng tư & bảo mật

- **Không có network request nào**: đã kiểm tra toàn bộ source — không
  `URLSession`, không `URLRequest`, không socket.
- **Không thu thập dữ liệu**, không analytics, không crash reporter.
- **Không truy cập cơ sở dữ liệu Messages** (`~/Library/Messages`),
  không đọc iMessage/Messenger, không Full Disk Access, không Accessibility.
- Mọi "tin nhắn" đều là dữ liệu giả lập trong RAM; tắt app là mất.
- Ảnh người dùng chọn qua NSOpenPanel được copy vào
  `~/Library/Application Support/imessage-mini/sent/` — chỉ app này đọc.
- Build script **không** tắt Gatekeeper, **không** sửa cài đặt bảo mật macOS,
  **không** tự cấp quyền hệ thống.

## Các giới hạn hiện tại

- Dữ liệu hội thoại **chỉ sống trong RAM** — tắt app là mất tin nhắn đã gửi.
- Chưa có badge số tin chưa đọc trên bong bóng.
- Chưa lưu/tải hội thoại từ disk; chưa tìm kiếm tin nhắn.
- Nút gọi thoại/video, GIF: giao diện demo (xem mục Tính năng demo).
- Chưa có bản build universal — app build theo kiến trúc của máy build
  (Apple Silicon hoặc Intel).
- Chưa kiểm chứng chữ ký Developer ID — app ký ad-hoc, chạy tốt khi build
  và mở trên chính máy đó.

## Cấu trúc source

```
imessage-mini/
├── build.sh                    # build + đóng gói ra dist/iMessage Mini.app
├── README.md
├── Resources/
│   ├── Info.plist              # LSUIElement (không icon Dock), target macOS 15+
│   └── Assets/                 # ảnh cục bộ + README quy ước đặt tên/bản quyền
└── Sources/
    ├── App/                    # AppDelegate, FloatingPanel, BubbleWindow
    ├── Models/                 # ChatModels, MessageModel, ConversationStore
    └── Views/                  # RootView, DesignTokens (bảng giá trị thiết kế),
                                # ChatHeader, ChatConversation, MessageBubble,
                                # MessageAvatar, ChatComposer, BubbleView,
                                # AvatarImage, HeaderDragArea, Color+Hex
```

## Xử lý sự cố

- `Không tìm thấy Swift compiler` → chạy `xcode-select --install` rồi build lại.
- App không mở sau build → kiểm tra Console.app xem log, hoặc chạy trực tiếp:
  `dist/iMessage\ Mini.app/Contents/MacOS/iMessage\ Mini` để xem lỗi.
- Đổi màn hình/rút màn hình ngoài → panel và bubble tự kéo về vùng hiển thị.
