# Messenger Bubble — bản DIY (tự học, tự sửa)

App macOS "bong bóng chat nổi" cho **Messenger thật**, viết bằng Swift thuần
(AppKit + WebKit), **1 file duy nhất** `Sources/main.swift`, có chú thích
tiếng Việt từng phần để bạn đọc-hiểu-tự sửa.

![concept](https://img.shields.io/badge/macOS-15%2B-blue) ![lang](https://img.shields.io/badge/Swift-AppKit%20%2B%20WebKit-orange)

## App làm được gì

- 🔵 **Bong bóng tròn nổi** luôn nằm trên mọi app (kể cả app fullscreen),
  kéo thả tự do, nhớ vị trí sau khi tắt.
- 💬 Bấm bong bóng → mở/đóng **cửa sổ chat mini** (mở `messenger.com` thật).
- 🔴 **Badge đỏ** hiện số tin chưa đọc (đọc từ tiêu đề trang web).
- 📌 Chuột phải → **"Ghim cửa sổ chat luôn nằm trên"** (bật/tắt always-on-top).
- 🎨 Chuột phải → **"Đổi màu bong bóng"** (xoay vòng 4 màu, app nhớ lựa chọn).
- 🔒 Tự đăng nhập Facebook 1 lần trong app; macOS nhớ cookie, lần sau khỏi nhập.
- 🚪 Chuột phải → đăng xuất / thoát. Nút đỏ chỉ *ẩn* cửa sổ chat, không tắt app.
- Không icon Dock (app phụ), thoát bằng menu chuột phải → *Thoát* hoặc `Cmd+Q`.
- 🧑‍🤝‍🧑 **Chat heads**: dải avatar tròn xếp dọc ở mép màn hình — mỗi head mở
  **thẳng** 1 đoạn chat (deep link `/t/<id>`), cửa sổ chat tự ẩn cột danh sách
  để chỉ còn khung tin nhắn. Bấm **+** để ghim đoạn chat mới (dán link `/t/...`
  copy từ trình duyệt + đặt tên), chuột phải vào head để xóa.

## Cách ghim 1 đoạn chat (chat heads)

1. Mở trình duyệt, vào `messenger.com`, bấm vào đoạn chat muốn ghim.
2. Copy URL trên thanh địa chỉ — nó có dạng `.../t/123456789...`.
3. Trong app, bấm nút **+** ở cuối dải heads → dán link → đặt tên → *Thêm*.
4. Từ nay bấm vào head là mở thẳng đoạn chat đó, không qua inbox chung.

Muốn quay lại danh sách tất cả đoạn chat: chuột phải vào bong bóng xanh →
**Về inbox chung**.

## Chạy thử (trên Mac)

```bash
chmod +x build.sh   # chỉ làm 1 lần
./build.sh          # mỗi lần sửa code xong chạy lại lệnh này
```

Yêu cầu: macOS 15 trở lên + Xcode (khuyên dùng) hoặc Command Line Tools
(`xcode-select --install`). **Lần đầu mở**, macOS có thể hỏi "mở app từ nhà
phát triển không xác định?" → vào *System Settings → Privacy & Security* bấm
**Open Anyway** (app do chính bạn build, ký ad-hoc local — an toàn).

Đăng nhập Facebook **ngay trong cửa sổ chat của app**, 1 lần duy nhất.

## Code được tổ chức thế nào

`Sources/main.swift` đọc từ trên xuống, 8 phần — mỗi phần là 1 bài học:

| Phần | Nội dung | Bài học |
|------|----------|---------|
| 1 | Hằng số (`Mini`) | Mọi thứ chỉnh nhanh: màu, kích thước, URL |
| 2 | JavaScript inject (`MiniJS`) | Cầu nối Web ↔ Native: đọc `document.title` |
| 3 | `UnreadScriptHandler` | Mẫu **weak wrapper** — tránh retain cycle với WebKit |
| 4 | `BubbleView` | Vẽ tay bằng `draw(_:)`, phân biệt kéo/bấm, menu chuột phải |
| 5 | `BubbleWindow` | **Công thức floating window**: `.borderless` + `.floating` + `canJoinAllSpaces` |
| 6 | `ChatWindow` | WKWebView + cookie persistent + nút đỏ chỉ ẩn cửa sổ |
| 7 | `AppDelegate` | Nối sự kiện bằng closure, nhớ dùng `[weak self]` |
| 8 | `main` (4 dòng) | Vì sao delegate phải là biến top-level |

## Bài tập tự làm (từ dễ → khó)

1. **Đổi màu mặc định**: thêm 1 màu vào `Mini.bubbleColors` (copy 1 dòng).
2. **Bong bóng to hơn**: đổi `bubbleDiameter` thành `80`, build lại xem.
3. **Đổi trang web**: sửa `chatURL` thành `https://www.facebook.com` — bạn sẽ
   thấy app này thật ra là "trình duyệt mini" cho bất kỳ trang nào.
4. **Thêm mục menu**: copy mẫu `menu.addItem(...)` trong `rightMouseDown`
   để thêm "Mở Facebook" chẳng hạn.
5. **Badge nhấp nháy**: trong `draw(_:)`, thử vẽ badge với alpha thay đổi
   theo thời gian (gợi ý: `Timer` + `needsDisplay = true`).
6. **Đọc thêm từ trang web**: viết thêm JS trong `MiniJS` để đọc tên người
   đang nhắn (gợi ý: `document.querySelector(...)`), gửi về Swift như `unread`.
7. **Avatar thật cho heads**: thay chữ cái trong `HeadView.draw` bằng
   `NSImage` tải từ URL (gợi ý: `NSImage(contentsOf:)` + cache vào
   `~/Library/Caches`).
8. **Badge riêng từng head**: hiện tại badge tổng nằm trên bong bóng xanh.
   Thử đọc số chưa đọc *từng thread* (gợi ý khó: phải mở từng thread hoặc
   đọc DOM của inbox).

## Giới hạn cần biết (nói thật)

- Đây là **web Messenger trong app của bạn**, không phải API chính thức của
  Meta. Nếu Meta đổi cấu trúc trang/tiêu đề, badge có thể đọc sai — cửa sổ
  chat vẫn dùng bình thường.
- Muốn phát hành lên App Store: iMessage/Messenger không có API đọc tin nhắn;
  cách bọc web này Apple thường không duyệt cho App Store (dùng cá nhân thì
  thoải mái).
- **PiP (Picture-in-Picture) thật** trên macOS là API của `AVKit` dành cho
  *video* — không áp dụng cho cửa sổ chat. Cái bạn cần cho chat chính là
  "always-on-top window", app này đã có (mục *Ghim cửa sổ chat luôn nằm trên*).

## Cấu trúc thư mục

```
messenger-bubble-diy/
├── Sources/main.swift      # toàn bộ app, 1 file, chú thích tiếng Việt
├── Resources/Info.plist    # thông tin bundle macOS
├── build.sh                # biên dịch + đóng gói thành .app
└── README.md               # file này
```

---
*Dự án cá nhân tự học — build bằng `./build.sh` trên Mac của bạn.*
