# Messenger Mini

Bong bóng chat nổi cho **Messenger thật** của bạn trên macOS — AppKit thuần +
WebKit, không SwiftUI, không thư viện bên thứ ba.

## Nó là gì?

Một bong bóng tròn màu xanh luôn nổi trên màn hình. Bấm vào → mở cửa sổ chat
chứa **web Messenger thật** (messenger.com). Có badge đỏ hiện số tin chưa đọc.

Nói thẳng: đây là web Messenger chạy trong app của bạn, **không phải API chính
thức** của Meta (Meta không mở API đọc inbox cá nhân). Cách này an toàn nhất
trong các đường tự làm vì bạn đăng nhập bằng chính trình duyệt của mình.

## Cài đặt & chạy

```bash
chmod +x build.sh
./build.sh
```

Script sẽ biên dịch, đóng gói `dist/Messenger Mini.app`, ký ad-hoc và tự mở app.
Yêu cầu macOS 15+ (chạy tốt trên Tahoe 26) và Xcode Command Line Tools.

## Đăng nhập lần đầu (quan trọng)

1. Mở app → cửa sổ chat hiện trang đăng nhập Messenger.
2. **Bạn tự gõ email + password Facebook của mình** ngay trong app, xác thực
   2 bước nếu có. Không ai khác thấy thông tin này.
3. Từ lần sau app tự nhớ phiên đăng nhập, mở là vào thẳng inbox.

> Điều kiện tiên quyết: bạn phải đăng nhập được messenger.com trên trình duyệt
> thường (Safari/Chrome). Nếu password hiện tại không đăng nhập được ở đâu thì
> app cũng không vào được — hãy reset password Facebook trước.

## Cách dùng

- **Bấm bong bóng**: ẩn/hiện cửa sổ chat.
- **Kéo bong bóng**: di chuyển (kéo < 4pt được tính là bấm). Vị trí được nhớ.
- **Badge đỏ**: số tin chưa đọc (đọc từ tiêu đề trang Messenger).
- **Chuột phải vào bong bóng**: Mở/đóng cửa sổ chat · Đăng xuất Messenger ·
  Thoát.
- **Nút đỏ cửa sổ chat**: chỉ ẩn cửa sổ, app vẫn chạy (bấm bong bóng để mở lại).
- **Cmd+Q**: thoát hẳn.

## Riêng tư

- Credential bạn gõ chỉ được gửi tới `messenger.com`, không qua trung gian nào.
- Phiên đăng nhập lưu trong cookie store của macOS
  (`~/Library/WebKit/...`), chung cơ chế với Safari.
- Đăng xuất: chuột phải bong bóng → "Đăng xuất Messenger…" (xóa sạch phiên
  trong app), hoặc đăng xuất ngay trong cửa sổ chat như trên web.

## Hạn chế đã biết (trung thực)

- Badge đọc từ tiêu đề trang (`"(3) Messenger"`). Nếu Meta đổi định dạng tiêu
  đề, badge có thể sai — cửa sổ chat vẫn dùng bình thường.
- UI là web Messenger, không phải giao diện native vẽ tay.
- App cần mạng để mở messenger.com.

## Xử lý sự cố

| Vấn đề | Cách xử lý |
|---|---|
| Không đăng nhập được | Kiểm tra lại password trên Safari trước; quên thì reset password Facebook |
| Badge không hiện số | Meta đổi title — chờ bản cập nhật chỗ đọc badge |
| macOS chặn mở app | Chuột phải vào app → Open (lần đầu), do app ký ad-hoc |
| Muốn đăng nhập acc khác | Chuột phải bong bóng → Đăng xuất Messenger… rồi đăng nhập lại |

## Cấu trúc

```
messenger-mini/
├── Sources/main.swift      # Toàn bộ app (1 file): bubble + badge + WKWebView
├── Resources/Info.plist    # LSUIElement (không hiện Dock), bundle id
├── build.sh                # Build → dist/Messenger Mini.app
└── README.md
```
