//
//  main.swift
//  Messenger Bubble (bản DIY — tự học, tự sửa)
//
//  ============================================================
//  ĐỌC TRƯỚC KHI CHẠY
//  ============================================================
//  Đây là app macOS "bong bóng chat nổi" cho Messenger THẬT:
//   • Một quả bong bóng tròn luôn nằm trên mọi app khác.
//   • Bấm bong bóng → mở/đóng cửa sổ chat mini (WKWebView mở messenger.com).
//   • Bạn TỰ đăng nhập Facebook 1 lần trong app; macOS nhớ cookie, lần sau khỏi nhập.
//   • JavaScript đọc document.title ("(3) Messenger") để lấy số tin chưa đọc
//     → hiện badge đỏ trên bong bóng.
//
//  Code này được viết theo kiểu "1 file duy nhất, đọc từ trên xuống dưới".
//  Mỗi PHẦN là một bài học nhỏ. Bạn cứ sửa từng phần rồi chạy lại ./build.sh
//  để xem thay đổi ngay — đó là cách học nhanh nhất.
//
//  YÊU CẦU: macOS 15+, Xcode hoặc Command Line Tools (xcode-select --install).
//  Build bằng:  ./build.sh
//  Lưu ý trung thực: đây là web Messenger trong app của bạn, KHÔNG phải API
//  chính thức của Meta. Nếu Meta đổi cấu trúc trang/tiêu đề, badge có thể đọc
//  sai — nhưng cửa sổ chat vẫn dùng bình thường.
//

import AppKit
import WebKit

// ============================================================
//  PHẦN 1 — HẰNG SỐ: "bảng điều khiển" của app
//  ------------------------------------------------------------
//  Mọi thứ bạn muốn chỉnh nhanh đều nằm ở đây: màu sắc, kích thước,
//  URL mở, ngưỡng kéo. Sửa số ở đây rồi build lại là thấy ngay kết quả.
// ============================================================

private enum Mini {
    /// Đường kính bong bóng (điểm ảnh). Thử đổi thành 80 rồi build lại xem.
    static let bubbleDiameter: CGFloat = 68

    /// Bảng màu bong bóng — bấm "Đổi màu bong bóng" trong menu chuột phải
    /// để xoay vòng. Thêm màu mới: copy 1 dòng NSColor và thêm vào mảng.
    static let bubbleColors: [NSColor] = [
        NSColor(red: 0.0, green: 0.52, blue: 1.0, alpha: 1.0),  // #0084FF xanh Messenger
        NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0), // #34C759 xanh lá
        NSColor(red: 1.0, green: 0.59, blue: 0.0, alpha: 1.0),   // #FF9500 cam
        NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0), // #AF52DE tím
    ]

    /// Trang web mở trong cửa sổ chat. Thử đổi thành "https://www.facebook.com"
    /// để thấy app này thật ra là "trình duyệt mini" cho bất kỳ trang nào.
    static let chatURL = URL(string: "https://www.messenger.com")!

    /// Khóa lưu vị trí bong bóng (UserDefaults = bộ nhớ nhỏ của app).
    static let originKey = "messengerBubbleDIY.bubbleOrigin"
    static let colorIndexKey = "messengerBubbleDIY.colorIndex"
    static let chatFrameKey = "NSWindow Frame MessengerBubbleDIYChat"

    /// Ngưỡng phân biệt "kéo" và "bấm": di chuyển quá 4pt mới tính là kéo.
    static let dragThreshold: CGFloat = 4

    /// Khóa lưu danh sách đoạn chat đã ghim (UserDefaults, dạng JSON).
    static let headsKey = "messengerBubbleDIY.chatHeads"
    static let headsOriginKey = "messengerBubbleDIY.headsOrigin"

    /// Deep link mở THẲNG 1 đoạn chat, bỏ qua inbox chung.
    /// Ví dụ: https://www.messenger.com/t/1234567890123456
    /// Đây là cách "chỉ mở đúng message": mỗi head giữ 1 thread ID.
    static func threadURL(_ id: String) -> URL {
        URL(string: "https://www.messenger.com/t/\(id)")!
    }

    /// Tách thread ID từ link messenger (chứa /t/123...) hoặc chuỗi số thuần.
    /// Trả về nil nếu không nhận ra → báo cho user nhập lại.
    static func extractThreadID(from text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = t.range(of: "/t/(\\d+)", options: .regularExpression) {
            return String(t[r].dropFirst(3)) // bỏ "/t/", giữ dãy số
        }
        if !t.isEmpty && t.allSatisfy(\.isNumber) && t.count >= 5 {
            return t
        }
        return nil
    }
}

// ============================================================
//  PHẦN 2 — JAVASCRIPT: "tai mắt" của app bên trong trang web
//  ------------------------------------------------------------
//  WKWebView chạy trang messenger.com, nhưng Swift ở "bên ngoài" không
//  nhìn thấy DOM. Giải pháp: inject 1 đoạn JS vào trang, JS đọc
//  document.title ("(3) Messenger") rồi gửi số về Swift qua
//  window.webkit.messageHandlers.unread.postMessage(...).
//
//  BÀI HỌC: đây là mẫu "Web ↔ Native bridge" — muốn đọc gì khác trên
//  trang (ví dụ tên người nhắn), bạn viết thêm JS tương tự.
// ============================================================

private enum MiniJS {
    static let unreadCounter = """
    (function() {
      function report() {
        try {
          var m = document.title.match(/^\\((\\d+)\\)/);
          window.webkit.messageHandlers.unread.postMessage(m ? parseInt(m[1], 10) : 0);
        } catch (e) { /* bỏ qua */ }
      }
      var tries = 0;
      var timer = setInterval(function() {
        tries += 1;
        if (document.head || tries > 150) {
          clearInterval(timer);
          if (document.head) {
            // Theo dõi thay đổi <title> → báo ngay khi có tin mới
            new MutationObserver(report).observe(document.head, {
              childList: true, subtree: true, characterData: true
            });
          }
          report();
        }
      }, 200);
    })();
    """

    /// JS ẩn cột danh sách chat bên trái → chỉ còn đúng khung tin nhắn.
    /// Được chạy sau khi trang load xong (xem AppDelegate.webView(didFinish:)),
    /// và CHỈ khi URL là 1 thread cụ thể (/t/<id>) để inbox chung vẫn nguyên.
    /// LƯU Ý TRUNG THỰC: selector dựa vào DOM hiện tại của Meta. Nếu một ngày
    /// không còn tác dụng, inspect lại trang và sửa selector này.
    static let hideSidebar = """
    (function(){
      var nav = document.querySelector('div[role="navigation"]');
      if (nav) { nav.style.display = 'none'; }
    })();
    """

    /// JS quét danh sách đoạn chat trong inbox: tìm mọi link chứa /t/<id>,
    /// lấy tên từ aria-label (fallback: dòng text đầu tiên), gửi JSON về
    /// Swift qua message handler "threads": [{id, name}, ...].
    /// LƯU Ý TRUNG THỰC: dựa vào DOM hiện tại của Meta. Nếu một ngày quét
    /// không ra gì, inspect lại trang và sửa selector 'a[href*="/t/"]'.
    static let threadList = """
    (function(){
      var out = [], seen = {};
      try {
        document.querySelectorAll('a[href*="/t/"]').forEach(function(a){
          var href = a.getAttribute('href') || '';
          var m = href.match(/\\/t\\/(\\d+)/);
          if (!m) return;
          var id = m[1];
          if (seen[id]) return;
          seen[id] = 1;
          var name = a.getAttribute('aria-label') || '';
          if (!name) {
            var t = (a.innerText || '').split('\\n')[0].trim();
            name = t.substring(0, 40);
          }
          // Avatar: lấy ảnh đầu tiên trong dòng chat (currentSrc cho ảnh lazy-load)
          var img = a.querySelector('img');
          var avatar = img ? (img.currentSrc || img.src || '') : '';
          if (name) out.push({id: id, name: name, avatar: avatar});
        });
        window.webkit.messageHandlers.threads.postMessage(JSON.stringify(out));
      } catch (e) { /* bo qua */ }
    })();
    """
}

// ============================================================
//  PHẦN 3 — CẦU NỐI JS → SWIFT (nhớ mẫu "weak wrapper" này)
//  ------------------------------------------------------------
//  WKUserContentController giữ handler RẤT LÂU. Nếu handler giữ mạnh
//  (strong) AppDelegate → tạo "retain cycle": 2 bên giữ nhau, không ai
//  được giải phóng → rò rỉ bộ nhớ. Wrapper này chỉ giữ WEAK.
//  ⚠️ Đây là lỗi kinh điển của người mới làm WebKit — nhớ kỹ.
// ============================================================

private final class UnreadScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: AppDelegate?

    func userContentController(_ ucc: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "unread" else { return }
        let count: Int
        if let n = message.body as? Int {
            count = n
        } else if let n = message.body as? Double {
            count = Int(n)
        } else {
            count = 0
        }
        target?.setUnreadCount(count)
    }
}

/// 1 đoạn chat quét được từ inbox: id + tên hiển thị + URL avatar (có thể rỗng).
private struct ScrapedThread: Codable {
    var id: String
    var name: String
    var avatar: String
}

/// Cầu nối JS → Swift cho kết quả quét inbox (handler "threads").
/// Cũng dùng mẫu weak wrapper như UnreadScriptHandler để tránh retain cycle.
private final class ThreadsScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: AppDelegate?

    func userContentController(_ ucc: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "threads",
              let json = message.body as? String else { return }
        target?.didReceiveThreads(json)
    }
}

// ============================================================
//  PHẦN 4 — BONG BÓNG: vẽ + kéo/thả + menu chuột phải
//  ------------------------------------------------------------
//  • draw(_:)   → vẽ hình tròn, icon, badge đỏ bằng tay (Core Graphics).
//  • mouseDown/Dragged/Up → tự làm "kéo", phân biệt kéo/bấm bằng ngưỡng.
//  • rightMouseDown       → menu ngữ cảnh.
//
//  BÀI HỌC: NSView + override draw là cách vẽ UI tùy biến hoàn toàn,
//  không cần ảnh PNG nào cả.
// ============================================================

private final class BubbleView: NSView {

    /// Số tin chưa đọc → vẽ badge đỏ. didSet: mỗi lần đổi là vẽ lại.
    var unreadCount: Int = 0 { didSet { needsDisplay = true } }

    /// Màu hiện tại của bong bóng (AppDelegate sẽ đổi khi bạn bấm "Đổi màu").
    var bubbleColor: NSColor = Mini.bubbleColors[0] { didSet { needsDisplay = true } }

    /// "Ổ cắm" callback: BubbleView không biết AppDelegate là ai, nó chỉ gọi
    /// các closure này. Mẫu này gọi là "delegation bằng closure" — đơn giản
    /// hơn delegate protocol khi chỉ có vài sự kiện.
    var onTap: (() -> Void)?
    var onToggleChat: (() -> Void)?
    var onOpenInbox: (() -> Void)?
    var onScanInbox: (() -> Void)?
    var onToggleAlwaysOnTop: (() -> Void)?
    var onCycleColor: (() -> Void)?
    var onLogout: (() -> Void)?
    var onQuit: (() -> Void)?

    /// AppDelegate cho BubbleView "mượn mắt" đọc trạng thái always-on-top
    /// để vẽ dấu ✓ trong menu. () -> Bool là "hàm không tham số, trả về Bool".
    var isAlwaysOnTop: () -> Bool = { false }

    private var pressPoint: NSPoint = .zero
    private var pressOrigin: NSPoint = .zero
    private var dragged = false

    // ---- Vẽ ----

    override func draw(_ dirtyRect: NSRect) {
        // 1) Hình tròn với màu hiện tại (inset 3pt để có viền mờ đẹp)
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        bubbleColor.setFill()
        circle.fill()

        // 2) Icon message.fill màu trắng, căn giữa.
        //    NSImage(systemSymbolName:) = SF Symbols có sẵn của macOS,
        //    không cần tải icon ở đâu.
        if let symbol = NSImage(systemSymbolName: "message.fill",
                                accessibilityDescription: "Messenger") {
            let iconSize = NSSize(width: 30, height: 30)
            // "Nhuộm trắng" icon: vẽ hình chữ nhật trắng rồi dùng
            // .destinationIn để giữ lại phần hình của symbol.
            let white = NSImage(size: iconSize, flipped: false) { rect in
                NSColor.white.setFill()
                rect.fill()
                symbol.draw(in: rect,
                            from: NSRect(origin: .zero, size: symbol.size),
                            operation: .destinationIn,
                            fraction: 1.0)
                return true
            }
            white.draw(in: NSRect(x: (bounds.width - iconSize.width) / 2,
                                  y: (bounds.height - iconSize.height) / 2,
                                  width: iconSize.width,
                                  height: iconSize.height))
        }

        // 3) Badge đỏ: số tin chưa đọc ở góc trên-phải.
        if unreadCount > 0 {
            let text = unreadCount > 99 ? "99+" : "\(unreadCount)"
            let font = NSFont.boldSystemFont(ofSize: 13)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            let ts = (text as NSString).size(withAttributes: attrs)
            let radius = max(13, ts.width / 2 + 7)
            let center = NSPoint(x: bounds.maxX - radius - 2,
                                 y: bounds.maxY - radius - 2)
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - radius,
                                       y: center.y - radius,
                                       width: radius * 2,
                                       height: radius * 2)).fill()
            (text as NSString).draw(at: NSPoint(x: center.x - ts.width / 2,
                                                y: center.y - ts.height / 2 + 1),
                                    withAttributes: attrs)
        }
    }

    // ---- Kéo / bấm ----

    override func mouseDown(with event: NSEvent) {
        // Ghi nhớ điểm bấm + vị trí cửa sổ lúc bắt đầu
        pressPoint = event.locationInWindow
        pressOrigin = window?.frame.origin ?? .zero
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let cur = event.locationInWindow
        let dx = cur.x - pressPoint.x
        let dy = cur.y - pressPoint.y
        // Quá ngưỡng mới tính là "đang kéo" (tránh bấm nhẹ bị tính là kéo)
        if abs(dx) + abs(dy) > Mini.dragThreshold { dragged = true }
        // Di chuyển cửa sổ theo con trỏ: vị trí mới = vị trí cũ + độ lệch
        win.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        // Không kéo → tính là "bấm" → mở/đóng cửa sổ chat
        if !dragged { onTap?() }
        clampOnScreen()
        saveOrigin()
    }

    /// Không cho bong bóng "trôi mất" khỏi màn hình: luôn chừa 40pt để túm lại.
    private func clampOnScreen() {
        guard let win = window, let screen = win.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        var o = win.frame.origin
        let s = win.frame.size
        o.x = min(max(o.x, vf.minX - s.width + 40), vf.maxX - 40)
        o.y = min(max(o.y, vf.minY - s.height + 40), vf.maxY - 40)
        win.setFrameOrigin(o)
    }

    /// Lưu vị trí vào UserDefaults → lần mở sau bong bóng ở đúng chỗ cũ.
    private func saveOrigin() {
        guard let o = window?.frame.origin else { return }
        UserDefaults.standard.set("\(o.x),\(o.y)", forKey: Mini.originKey)
    }

    // ---- Menu chuột phải ----

    @objc private func menuToggleChat(_ sender: NSMenuItem) { onToggleChat?() }
    @objc private func menuOpenInbox(_ sender: NSMenuItem) { onOpenInbox?() }
    @objc private func menuScanInbox(_ sender: NSMenuItem) { onScanInbox?() }
    @objc private func menuToggleAlwaysOnTop(_ sender: NSMenuItem) { onToggleAlwaysOnTop?() }
    @objc private func menuCycleColor(_ sender: NSMenuItem) { onCycleColor?() }
    @objc private func menuLogout(_ sender: NSMenuItem) { onLogout?() }
    @objc private func menuQuit(_ sender: NSMenuItem) { onQuit?() }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        func item(_ title: String, _ sel: Selector) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            return i
        }
        menu.addItem(item("Mở/đóng cửa sổ chat", #selector(menuToggleChat)))
        menu.addItem(item("Về inbox chung", #selector(menuOpenInbox)))
        menu.addItem(item("Ghim đoạn chat từ inbox…", #selector(menuScanInbox)))
        // Dấu ✓ cho biết cửa sổ chat đang "ghim" luôn-nổi hay không
        let pinItem = item("Ghim cửa sổ chat luôn nằm trên", #selector(menuToggleAlwaysOnTop))
        pinItem.state = isAlwaysOnTop() ? .on : .off
        menu.addItem(pinItem)
        menu.addItem(item("Đổi màu bong bóng", #selector(menuCycleColor)))
        menu.addItem(item("Đăng xuất Messenger…", #selector(menuLogout)))
        menu.addItem(.separator())
        menu.addItem(item("Thoát", #selector(menuQuit)))
        menu.popUp(positioning: nil,
                   at: convert(event.locationInWindow, from: nil),
                   in: self)
    }
}

// ============================================================
//  PHẦN 5 — CỬA SỔ BONG BÓNG: "phép thuật" nằm ở 3 dòng này
//  ------------------------------------------------------------
//  • styleMask: .borderless + .nonactivatingPanel → cửa sổ không viền,
//    bấm vào không "cướp" focus của app khác (bạn vẫn gõ Word bình thường).
//  • level = .floating → LUÔN NẰM TRÊN cửa sổ thường.
//  • collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] →
//    hiện trên mọi Space / màn hình, kể cả app fullscreen.
//  Đây chính là công thức của "Floating Window / Always-on-top" trên macOS.
// ============================================================

private final class BubbleWindow: NSPanel {

    let bubbleView = BubbleView()

    init() {
        let d = Mini.bubbleDiameter
        super.init(contentRect: NSRect(x: 0, y: 0, width: d, height: d),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false          // nền trong suốt → chỉ thấy hình tròn
        backgroundColor = .clear
        hasShadow = true
        level = .floating         // ← "luôn nằm trên" ở đây
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false // app khác active, bong bóng vẫn hiện
        bubbleView.frame = NSRect(x: 0, y: 0, width: d, height: d)
        bubbleView.autoresizingMask = [.width, .height]
        contentView = bubbleView
        restoreOrigin()
    }

    /// Đọc vị trí đã lưu; chưa có thì đặt ở góc dưới-phải màn hình.
    private func restoreOrigin() {
        let d = Mini.bubbleDiameter
        var origin: NSPoint?
        if let s = UserDefaults.standard.string(forKey: Mini.originKey) {
            let parts = s.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { origin = NSPoint(x: parts[0], y: parts[1]) }
        }
        if origin == nil, let vf = NSScreen.main?.visibleFrame {
            origin = NSPoint(x: vf.maxX - d - 24, y: vf.minY + 24)
        }
        setFrameOrigin(origin ?? .zero)
    }
}

// ============================================================
//  PHẦN 5B — CHAT HEADS: dải avatar nổi mở thẳng từng đoạn chat
//  ------------------------------------------------------------
//  Đúng ý bạn hỏi: một dải tròn xếp dọc ở mép màn hình,
//  mỗi "head" = 1 đoạn chat đã ghim. Bấm head → cửa sổ chat mở THẲNG
//  thread đó qua deep link /t/<id>, không đi qua inbox chung.
//  Thêm head: bấm nút "+" → dán link đoạn chat (mở đoạn chat trên trình
//  duyệt, copy URL có dạng .../t/123456...) + đặt tên hiển thị.
// ============================================================

/// 1 đoạn chat đã ghim: tên hiển thị + thread ID + URL avatar (nếu có).
/// Lưu JSON trong UserDefaults. avatarURL có giá trị mặc định nil nên
/// các head đã lưu từ trước (chưa có avatar) vẫn đọc được bình thường.
private struct ChatHead: Codable {
    var name: String
    var threadID: String
    var avatarURL: String? = nil
}

/// Tải + cache avatar: nhớ trong RAM (NSCache) và lưu file vào
/// ~/Library/Caches để lần mở sau không phải tải lại.
/// BÀI HỌC: đây là mẫu "async image loading" cơ bản nhất của AppKit.
private final class AvatarLoader {
    static let shared = AvatarLoader()
    private let cache = NSCache<NSString, NSImage>()
    private let dir: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("messenger-bubble-diy/avatars", isDirectory: true)

    func load(urlString: String, key: String, completion: @escaping (NSImage?) -> Void) {
        if let img = cache.object(forKey: key as NSString) {
            completion(img); return
        }
        let file = dir.appendingPathComponent(key)
        if let data = try? Data(contentsOf: file), let img = NSImage(data: data) {
            cache.setObject(img, forKey: key as NSString)
            completion(img); return
        }
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let img = NSImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }; return
            }
            try? FileManager.default.createDirectory(at: self.dir,
                                                     withIntermediateDirectories: true)
            try? data.write(to: file)
            self.cache.setObject(img, forKey: key as NSString)
            DispatchQueue.main.async { completion(img) }
        }.resume()
    }
}

/// 1 head tròn: vẽ chữ cái đầu của tên, màu theo hash tên (nhận mặt bằng màu).
/// BÀI TẬP nâng cấp: thay chữ cái bằng ảnh avatar (NSImage từ URL/file local).
private final class HeadView: NSView {
    let head: ChatHead
    var onSelect: (() -> Void)?
    var onRemove: (() -> Void)?

    /// Ảnh avatar (tải bất đồng bộ). Có ảnh thì vẽ ảnh, chưa có thì vẽ chữ cái.
    var avatarImage: NSImage? { didSet { needsDisplay = true } }

    init(head: ChatHead, diameter: CGFloat) {
        self.head = head
        super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
    }
    required init?(coder: NSCoder) { nil }

    private var circleColor: NSColor {
        let palette: [NSColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemPurple,
            .systemPink, .systemTeal, .systemIndigo, .systemBrown,
        ]
        return palette[abs(head.name.hashValue) % palette.count]
    }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 2, dy: 2)
        // Nền tròn (lộ ra nếu ảnh trong suốt hoặc chưa tải xong)
        circleColor.setFill()
        NSBezierPath(ovalIn: r).fill()

        if let img = avatarImage, img.size.width > 0, img.size.height > 0 {
            // Vẽ ảnh center-crop trong hình tròn: clip theo đường tròn rồi vẽ
            // ảnh phóng to vừa khít (mẫu "avatar tròn" kinh điển).
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(ovalIn: r).addClip()
            let iw = img.size.width, ih = img.size.height
            let s = max(r.width / iw, r.height / ih)
            let dw = iw * s, dh = ih * s
            img.draw(in: NSRect(x: r.minX + (r.width - dw) / 2,
                                y: r.minY + (r.height - dh) / 2,
                                width: dw, height: dh),
                     from: NSRect(origin: .zero, size: img.size),
                     operation: .copy,
                     fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            return
        }

        // Fallback: chữ cái đầu của tên
        let initial = String(head.name.prefix(1)).uppercased()
        let font = NSFont.boldSystemFont(ofSize: bounds.width * 0.42)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let ts = (initial as NSString).size(withAttributes: attrs)
        (initial as NSString).draw(at: NSPoint(x: (bounds.width - ts.width) / 2,
                                               y: (bounds.height - ts.height) / 2 + 1),
                                   withAttributes: attrs)
    }

    override func mouseUp(with event: NSEvent) { onSelect?() }

    @objc private func menuRemove(_ sender: NSMenuItem) { onRemove?() }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let i = NSMenuItem(title: "Xóa \"\(head.name)\" khỏi danh sách",
                           action: #selector(menuRemove), keyEquivalent: "")
        i.target = self
        menu.addItem(i)
        menu.popUp(positioning: nil,
                   at: convert(event.locationInWindow, from: nil),
                   in: self)
    }
}

/// Nền thanh dọc chứa các head: bo góc, đen mờ (giống ảnh mẫu).
private final class BarView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let p = NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16)
        NSColor(white: 0.16, alpha: 0.92).setFill()
        p.fill()
    }
}

/// Panel dọc chứa các head + nút "+". Nổi mọi Space, không viền, không Dock.
private final class HeadsPanel: NSPanel {
    static let width: CGFloat = 60
    static let headDiameter: CGFloat = 46

    private let container = NSView()
    var onAdd: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 120),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        container.frame = NSRect(x: 0, y: 0, width: Self.width, height: 120)
        container.autoresizingMask = [.width, .height]
        contentView = container
        restoreOrigin()
    }

    /// Dựng lại toàn bộ head (gọi mỗi khi thêm/xóa). Giữ mép trên cố định
    /// để panel không "nhảy" khi danh sách dài ra.
    func rebuild(heads: [ChatHead],
                 onSelect: @escaping (ChatHead) -> Void,
                 onRemove: @escaping (ChatHead) -> Void) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let d = Self.headDiameter
        let gap: CGFloat = 8
        let h = gap + CGFloat(heads.count + 1) * (d + gap) // +1 cho nút "+"
        var f = frame
        let oldMaxY = f.maxY
        f.size = NSSize(width: Self.width, height: h)
        f.origin.y = oldMaxY - h
        setFrame(f, display: true)
        container.frame = NSRect(origin: .zero, size: contentRect(forFrameRect: f).size)

        // Nền thanh (vẽ trước, nằm dưới các head)
        let bar = BarView()
        bar.frame = NSRect(origin: .zero,
                           size: NSSize(width: Self.width, height: h))
        bar.autoresizingMask = [.width, .height]
        container.addSubview(bar)

        var y = h - gap - d
        for head in heads {
            let v = HeadView(head: head, diameter: d)
            v.frame = NSRect(x: (Self.width - d) / 2, y: y, width: d, height: d)
            v.onSelect = { onSelect(head) }
            v.onRemove = { onRemove(head) }
            container.addSubview(v)
            y -= (d + gap)
        }
        // Nút "+" thêm đoạn chat mới
        let plus = NSButton(frame: NSRect(x: (Self.width - d) / 2, y: y,
                                          width: d, height: d))
        plus.bezelStyle = .circular
        plus.title = "+"
        plus.font = NSFont.systemFont(ofSize: 24)
        plus.target = self
        plus.action = #selector(didTapAdd)
        container.addSubview(plus)
    }

    @objc private func didTapAdd() { onAdd?() }

    /// Tìm HeadView theo thread ID (để nạp avatar / tính vị trí).
    func headView(forThreadID id: String) -> HeadView? {
        container.subviews.compactMap { $0 as? HeadView }
            .first { $0.head.threadID == id }
    }

    /// Tọa độ Y giữa head trên màn hình (để đặt thẻ chat ngang tầm head).
    func screenYCenter(forThreadID id: String) -> CGFloat? {
        guard let hv = headView(forThreadID: id),
              let win = hv.window else { return nil }
        return win.convertToScreen(hv.convert(hv.bounds, to: nil)).midY
    }

    private func restoreOrigin() {
        var origin: NSPoint?
        if let s = UserDefaults.standard.string(forKey: Mini.headsOriginKey) {
            let parts = s.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { origin = NSPoint(x: parts[0], y: parts[1]) }
        }
        if origin == nil, let vf = NSScreen.main?.visibleFrame {
            origin = NSPoint(x: vf.maxX - Self.width - 8,
                             y: vf.midY - frame.height / 2)
        }
        setFrameOrigin(origin ?? .zero)
    }
}

// ============================================================
//  PHẦN 6 — THẺ CHAT: WKWebView trong "thẻ trắng bo góc" nổi
//  ------------------------------------------------------------
//  Giống ảnh mẫu: thẻ trắng bo góc, không thanh tiêu đề, có đuôi tam
//  giác chỉ về phía dải heads. Kéo thẻ bằng thanh trắng 16pt ở đỉnh
//  (webview nằm gọn bên dưới nên không che nút bấm của trang web).
//  • websiteDataStore = .default() → cookie PERSISTENT: đăng nhập 1 lần.
//  • isReleasedWhenClosed = false → ẩn/hiện chứ không hủy.
// ============================================================

/// Thanh kéo 16pt ở đỉnh thẻ: kéo để di chuyển cả thẻ chat.
private final class DragStripView: NSView {
    var onDrag: ((CGPoint) -> Void)?
    private var start: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        start = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        let cur = event.locationInWindow
        onDrag?(CGPoint(x: cur.x - start.x, y: cur.y - start.y))
        start = cur
    }
}

/// Đuôi tam giác trắng ở mép phải thẻ, chỉ về phía dải heads.
private final class TailView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 2, y: 2))
        p.line(to: NSPoint(x: 2, y: bounds.height - 2))
        p.line(to: NSPoint(x: bounds.width - 1, y: bounds.height / 2))
        p.close()
        NSColor.white.setFill()
        p.fill()
    }
}

private final class ChatWindow: NSPanel {

    static let cardSize = NSSize(width: 380, height: 560)
    private static let stripHeight: CGFloat = 16

    let webView: WKWebView
    private let dragStrip = DragStripView()
    private let tailView = TailView()

    init(unreadHandler: UnreadScriptHandler, threadsHandler: ThreadsScriptHandler) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: MiniJS.unreadCounter,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true))
        ucc.add(unreadHandler, name: "unread")
        ucc.add(threadsHandler, name: "threads")
        config.userContentController = ucc

        webView = WKWebView(frame: .zero, configuration: config)

        super.init(contentRect: NSRect(origin: .zero, size: Self.cardSize),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        // Container trắng bo góc 18pt
        let container = NSView(frame: NSRect(origin: .zero, size: Self.cardSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]
        contentView = container

        // WebView nằm dưới thanh kéo
        webView.frame = NSRect(x: 0, y: 0,
                               width: Self.cardSize.width,
                               height: Self.cardSize.height - Self.stripHeight)
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        // Thanh kéo ở đỉnh (trắng, hòa vào thẻ)
        dragStrip.frame = NSRect(x: 0,
                                 y: Self.cardSize.height - Self.stripHeight,
                                 width: Self.cardSize.width,
                                 height: Self.stripHeight)
        dragStrip.autoresizingMask = [.width, .minYMargin]
        dragStrip.onDrag = { [weak self] d in
            guard let w = self else { return }
            w.setFrameOrigin(NSPoint(x: w.frame.origin.x + d.x,
                                     y: w.frame.origin.y + d.y))
        }
        container.addSubview(dragStrip)

        // Đuôi tam giác ở mép phải, giữa thẻ (sẽ dời theo head được bấm)
        tailView.frame = NSRect(x: Self.cardSize.width - 18,
                                y: Self.cardSize.height / 2 - 13,
                                width: 18, height: 26)
        tailView.autoresizingMask = [.minXMargin]
        container.addSubview(tailView)

        minSize = NSSize(width: 300, height: 420)
        webView.load(URLRequest(url: Mini.chatURL))
    }

    /// Dời đuôi tam giác tới vị trí Y (tọa độ trong thẻ) của head vừa bấm.
    func moveTail(toLocalY y: CGFloat) {
        var f = tailView.frame
        let h = ChatWindow.cardSize.height
        f.origin.y = min(max(y - f.height / 2, 8), h - f.height - 20)
        tailView.frame = f
    }

    /// Bật/tắt "luôn nằm trên" cho thẻ chat.
    /// level .floating = trên hết; .normal = cửa sổ thường.
    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }
}

// ============================================================
//  PHẦN 7 — APPDELEGATE: "nhạc trưởng" nối mọi thứ lại
//  ------------------------------------------------------------
//  • applicationDidFinishLaunching: dựng bong bóng + cửa sổ chat,
//    cắm các closure onTap/onLogout/... vào BubbleView.
//  • [weak self] trong closure: TRÁNH retain cycle (bài học như PHẦN 3).
//    Quên "weak" → AppDelegate và BubbleView giữ nhau → rò rỉ.
// ============================================================

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate {

    private var bubble: BubbleWindow!
    private var chat: ChatWindow!
    private var headsPanel: HeadsPanel!
    private var heads: [ChatHead] = []
    private var openThreadID: String? // thread đang mở trong thẻ (nil = inbox/không có)
    private let scriptHandler = UnreadScriptHandler()
    private let threadsScriptHandler = ThreadsScriptHandler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .accessory = app "phụ": KHÔNG hiện icon trên Dock
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        scriptHandler.target = self
        threadsScriptHandler.target = self

        bubble = BubbleWindow()
        chat = ChatWindow(unreadHandler: scriptHandler,
                          threadsHandler: threadsScriptHandler)
        chat.delegate = self
        chat.webView.navigationDelegate = self

        // Khôi phục màu bong bóng đã chọn lần trước
        let colorIndex = UserDefaults.standard.integer(forKey: Mini.colorIndexKey)
        bubble.bubbleView.bubbleColor = Mini.bubbleColors[colorIndex % Mini.bubbleColors.count]

        // Cắm dây: sự kiện từ BubbleView → hành động của AppDelegate
        let bv = bubble.bubbleView
        bv.isAlwaysOnTop = { [weak self] in self?.chat.level == .floating }
        bv.onTap = { [weak self] in self?.toggleChat() }
        bv.onToggleChat = { [weak self] in self?.toggleChat() }
        bv.onOpenInbox = { [weak self] in self?.openInbox() }
        bv.onScanInbox = { [weak self] in self?.scanInbox() }
        bv.onToggleAlwaysOnTop = { [weak self] in self?.toggleAlwaysOnTop() }
        bv.onCycleColor = { [weak self] in self?.cycleBubbleColor() }
        bv.onLogout = { [weak self] in self?.logout() }
        bv.onQuit = { NSApp.terminate(nil) }

        bubble.orderFrontRegardless()

        // Dải chat heads (PHẦN 5B)
        loadHeads()
        headsPanel = HeadsPanel()
        headsPanel.onAdd = { [weak self] in self?.addChat() }
        rebuildHeads()
        headsPanel.orderFrontRegardless()
    }

    // ---- Badge tin chưa đọc (được gọi từ PHẦN 3) ----

    func setUnreadCount(_ count: Int) {
        // JS gọi về trên background thread → phải nhảy về main thread
        // mới được đụng vào UI. Quên dòng này = crash ngẫu nhiên.
        DispatchQueue.main.async { [weak self] in
            self?.bubble.bubbleView.unreadCount = count
        }
    }

    // ---- Mở/đóng thẻ chat ----

    /// Bấm bong bóng: ẩn thẻ đang mở, hoặc mở lại thẻ ở vị trí mặc định
    /// (cạnh dải heads, giữa màn hình).
    private func toggleChat() {
        if chat.isVisible {
            chat.orderOut(nil)
            openThreadID = nil
        } else {
            openThreadID = nil
            placeCard(nearScreenY: headsPanel.frame.midY)
            showChatWindow()
        }
    }

    /// Đảo trạng thái "luôn nằm trên" của cửa sổ chat.
    private func toggleAlwaysOnTop() {
        chat.setAlwaysOnTop(chat.level != .floating)
    }

    /// Xoay vòng màu bong bóng + lưu lại để lần sau mở vẫn nhớ.
    private func cycleBubbleColor() {
        let current = UserDefaults.standard.integer(forKey: Mini.colorIndexKey)
        let next = (current + 1) % Mini.bubbleColors.count
        UserDefaults.standard.set(next, forKey: Mini.colorIndexKey)
        bubble.bubbleView.bubbleColor = Mini.bubbleColors[next]
    }

    // ---- Chat heads (PHẦN 5B): mở thẳng từng đoạn chat ----

    private func loadHeads() {
        guard let data = UserDefaults.standard.data(forKey: Mini.headsKey),
              let decoded = try? JSONDecoder().decode([ChatHead].self, from: data)
        else { heads = []; return }
        heads = decoded
    }

    private func saveHeads() {
        if let data = try? JSONEncoder().encode(heads) {
            UserDefaults.standard.set(data, forKey: Mini.headsKey)
        }
    }

    private func rebuildHeads() {
        headsPanel.rebuild(heads: heads,
                           onSelect: { [weak self] head in self?.openThread(head) },
                           onRemove: { [weak self] head in self?.removeHead(head) })
        // Nạp avatar bất đồng bộ cho từng head (có cache, lần sau mở là có ngay)
        for head in heads {
            guard let url = head.avatarURL,
                  let hv = headsPanel.headView(forThreadID: head.threadID) else { continue }
            AvatarLoader.shared.load(urlString: url, key: head.threadID) { img in
                hv.avatarImage = img
            }
        }
    }

    /// Mở THẲNG 1 đoạn chat bằng deep link /t/<id> — không qua inbox chung.
    /// Bấm lại head đang mở → đóng thẻ (toggle). Thẻ tự đặt cạnh head vừa bấm,
    /// đuôi tam giác chỉ đúng vào head đó (giống ảnh mẫu).
    private func openThread(_ head: ChatHead) {
        if chat.isVisible, openThreadID == head.threadID {
            chat.orderOut(nil)
            openThreadID = nil
            return
        }
        openThreadID = head.threadID
        chat.webView.load(URLRequest(url: Mini.threadURL(head.threadID)))
        let y = headsPanel.screenYCenter(forThreadID: head.threadID)
            ?? headsPanel.frame.midY
        placeCard(nearScreenY: y)
        showChatWindow()
    }

    /// Về lại inbox chung (danh sách tất cả đoạn chat).
    private func openInbox() {
        openThreadID = nil
        chat.webView.load(URLRequest(url: Mini.chatURL))
        placeCard(nearScreenY: headsPanel.frame.midY)
        showChatWindow()
    }

    /// Đặt thẻ chat sát mép trái dải heads, ngang tầm head vừa bấm,
    /// đuôi tam giác chỉ đúng vào head đó.
    private func placeCard(nearScreenY screenY: CGFloat) {
        let size = ChatWindow.cardSize
        guard let screen = headsPanel.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        var x = headsPanel.frame.minX - size.width - 14
        x = max(x, vf.minX + 8)
        var y = screenY - size.height / 2
        y = min(max(y, vf.minY + 8), vf.maxY - size.height - 8)
        chat.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
        chat.moveTail(toLocalY: screenY - y)
    }

    private func showChatWindow() {
        if !chat.isVisible {
            chat.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func removeHead(_ head: ChatHead) {
        heads.removeAll { $0.threadID == head.threadID }
        saveHeads()
        rebuildHeads()
    }

    /// Dialog thêm đoạn chat: dán link (hoặc thread ID) + đặt tên hiển thị.
    /// Cách lấy link: mở đoạn chat trên trình duyệt → copy URL trên thanh
    /// địa chỉ (có dạng .../t/123456...) → dán vào ô đầu tiên.
    private func addChat() {
        let alert = NSAlert()
        alert.messageText = "Ghim đoạn chat"
        alert.informativeText = "Dán link đoạn chat (URL chứa /t/ + dãy số) hoặc dãy số thread ID."
        let linkField = NSTextField(frame: NSRect(x: 0, y: 28, width: 300, height: 24))
        linkField.placeholderString = "Link hoặc thread ID, ví dụ …/t/123456789"
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        nameField.placeholderString = "Tên hiển thị, ví dụ: Sếp Minh"
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 56))
        box.addSubview(linkField)
        box.addSubview(nameField)
        alert.accessoryView = box
        alert.addButton(withTitle: "Thêm")
        alert.addButton(withTitle: "Hủy")
        alert.window.initialFirstResponder = linkField
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let id = Mini.extractThreadID(from: linkField.stringValue) else {
            let err = NSAlert()
            err.messageText = "Không nhận ra link/ID"
            err.informativeText = "Hãy dán URL đoạn chat (chứa /t/ + dãy số) hoặc dãy số ID."
            err.runModal()
            return
        }
        guard !heads.contains(where: { $0.threadID == id }) else { return } // đã ghim rồi
        let rawName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        heads.append(ChatHead(name: rawName.isEmpty ? "Chat \(heads.count + 1)" : rawName,
                              threadID: id))
        saveHeads()
        rebuildHeads()
    }

    // ---- Quét inbox: lấy danh sách đoạn chat từ chính trang web ----

    /// Mở inbox, đợi trang load rồi chạy JS quét danh sách thread.
    /// Con số 4 giây là heuristic (đoán thời gian load) — nếu mạng chậm,
    /// tăng lên. BÀI HỌC: polling/delay là cách đơn giản nhất để đợi SPA;
    /// cách "sạch" hơn là observe DOM, nhưng phức tạp hơn nhiều.
    private func scanInbox() {
        chat.webView.load(URLRequest(url: Mini.chatURL))
        showChatWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.chat.webView.evaluateJavaScript(MiniJS.threadList,
                                                  completionHandler: nil)
        }
    }

    /// Nhận JSON [{id, name}] từ JS (được gọi trên background thread).
    func didReceiveThreads(_ json: String) {
        let list: [ScrapedThread]
        if let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ScrapedThread].self, from: data),
           !decoded.isEmpty {
            list = decoded
        } else {
            list = []
        }
        DispatchQueue.main.async { [weak self] in
            self?.handleScannedThreads(list)
        }
    }

    private func handleScannedThreads(_ list: [ScrapedThread]) {
        guard !list.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Không quét được đoạn chat nào"
            alert.informativeText = "Hãy chắc chắn cửa sổ chat đang mở inbox (danh sách đoạn chat), rồi thử lại. Nếu vẫn không được, Meta có thể đã đổi cấu trúc trang — dùng cách dán link thủ công."
            alert.runModal()
            return
        }
        // Lọc bớt những thread đã ghim rồi cho gọn
        let fresh = list.filter { t in !heads.contains(where: { $0.threadID == t.id }) }
        guard !fresh.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Tất cả đoạn chat tìm thấy đều đã được ghim"
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Chọn đoạn chat để ghim"
        alert.informativeText = "Danh sách lấy trực tiếp từ inbox của bạn."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        popup.addItems(withTitles: fresh.map { $0.name })
        alert.accessoryView = popup
        alert.addButton(withTitle: "Ghim")
        alert.addButton(withTitle: "Hủy")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let idx = popup.indexOfSelectedItem
        guard fresh.indices.contains(idx) else { return }
        let t = fresh[idx]
        heads.append(ChatHead(name: t.name, threadID: t.id,
                              avatarURL: t.avatar.isEmpty ? nil : t.avatar))
        saveHeads()
        rebuildHeads()
    }

    // ---- WKNavigationDelegate: ẩn cột chat-list khi đang xem thread ----

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Chỉ ẩn sidebar khi URL là 1 thread cụ thể (/t/<id>);
        // inbox chung (openInbox) giữ nguyên để còn duyệt danh sách.
        guard webView.url?.path.contains("/t/") == true else { return }
        webView.evaluateJavaScript(MiniJS.hideSidebar, completionHandler: nil)
    }

    /// Ẩn thẻ thay vì đóng hẳn (bong bóng/heads vẫn còn để mở lại).
    /// (Thẻ borderless không có nút đỏ, nhưng giữ lại cho an toàn.)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        openThreadID = nil
        return false
    }

    // ---- Đăng xuất: xóa cookie trong app ----

    private func logout() {
        let alert = NSAlert()
        alert.messageText = "Đăng xuất Messenger?"
        alert.informativeText = "Phiên đăng nhập trong app sẽ bị xóa. Lần mở sau bạn sẽ phải đăng nhập lại."
        alert.addButton(withTitle: "Đăng xuất")
        alert.addButton(withTitle: "Hủy")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [weak self] in
            guard let self else { return }
            self.chat.webView.load(URLRequest(url: Mini.chatURL))
            self.setUnreadCount(0)
        }
    }

    // ---- Menu app (để có Cmd+Q) ----

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Thoát Messenger Bubble",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
}

// ============================================================
//  PHẦN 8 — ĐIỂM VÀO: chỉ 4 dòng
//  ------------------------------------------------------------
//  Không dùng @main. delegate là biến top-level → sống suốt vòng đời
//  process (biến local trong hàm sẽ bị giải phóng ngay → app chết).
//  app.run() bắt đầu vòng lặp sự kiện (event loop) của macOS.
// ============================================================

// QUY TẮC SWIFT cần nhớ: một khai báo không được "lộ" hơn kiểu của nó.
// AppDelegate là `private` → 2 biến top-level dưới đây cũng phải `private`
// (bỏ chữ private là lỗi biên dịch ngay, như bạn vừa gặp).
private let app = NSApplication.shared
private let delegate = AppDelegate() // biến top-level: sống suốt vòng đời process
app.delegate = delegate
app.run()
