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
//  PHẦN 6 — CỬA SỔ CHAT: WKWebView bọc messenger.com
//  ------------------------------------------------------------
//  • websiteDataStore = .default() → cookie PERSISTENT của hệ thống:
//    đăng nhập 1 lần, tắt app mở lại vẫn còn (giống Safari).
//  • isReleasedWhenClosed = false + windowShouldClose → nút đỏ chỉ ẨN
//    cửa sổ, không hủy (bấm bong bóng là mở lại ngay).
//  • setFrameAutosaveName → macOS tự nhớ kích thước/vị trí cửa sổ.
// ============================================================

private final class ChatWindow: NSWindow {

    let webView: WKWebView

    init(scriptHandler: UnreadScriptHandler) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: MiniJS.unreadCounter,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true))
        ucc.add(scriptHandler, name: "unread")
        config.userContentController = ucc

        webView = WKWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]

        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
                   styleMask: [.titled, .closable, .miniaturizable, .resizable],
                   backing: .buffered,
                   defer: false)
        title = "Messenger"
        minSize = NSSize(width: 320, height: 480)
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        contentView = webView
        setFrameAutosaveName(Mini.chatFrameKey)
        webView.load(URLRequest(url: Mini.chatURL))
    }

    /// Bật/tắt "luôn nằm trên" cho cửa sổ chat.
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

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var bubble: BubbleWindow!
    private var chat: ChatWindow!
    private let scriptHandler = UnreadScriptHandler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .accessory = app "phụ": KHÔNG hiện icon trên Dock
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        scriptHandler.target = self

        bubble = BubbleWindow()
        chat = ChatWindow(scriptHandler: scriptHandler)
        chat.delegate = self
        positionChatDefaultIfNeeded()

        // Khôi phục màu bong bóng đã chọn lần trước
        let colorIndex = UserDefaults.standard.integer(forKey: Mini.colorIndexKey)
        bubble.bubbleView.bubbleColor = Mini.bubbleColors[colorIndex % Mini.bubbleColors.count]

        // Cắm dây: sự kiện từ BubbleView → hành động của AppDelegate
        let bv = bubble.bubbleView
        bv.isAlwaysOnTop = { [weak self] in self?.chat.level == .floating }
        bv.onTap = { [weak self] in self?.toggleChat() }
        bv.onToggleChat = { [weak self] in self?.toggleChat() }
        bv.onToggleAlwaysOnTop = { [weak self] in self?.toggleAlwaysOnTop() }
        bv.onCycleColor = { [weak self] in self?.cycleBubbleColor() }
        bv.onLogout = { [weak self] in self?.logout() }
        bv.onQuit = { NSApp.terminate(nil) }

        bubble.orderFrontRegardless()
    }

    // ---- Badge tin chưa đọc (được gọi từ PHẦN 3) ----

    func setUnreadCount(_ count: Int) {
        // JS gọi về trên background thread → phải nhảy về main thread
        // mới được đụng vào UI. Quên dòng này = crash ngẫu nhiên.
        DispatchQueue.main.async { [weak self] in
            self?.bubble.bubbleView.unreadCount = count
        }
    }

    // ---- Mở/đóng cửa sổ chat ----

    private func toggleChat() {
        if chat.isVisible {
            chat.orderOut(nil)
        } else {
            chat.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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

    /// Lần đầu chưa có frame lưu: đặt cửa sổ chat bên trái bong bóng.
    private func positionChatDefaultIfNeeded() {
        guard UserDefaults.standard.string(forKey: Mini.chatFrameKey) == nil,
              let vf = NSScreen.main?.visibleFrame else { return }
        let bf = bubble.frame
        let cs = chat.frame.size
        var x = bf.minX - cs.width - 12
        var y = bf.minY
        x = min(max(x, vf.minX + 12), vf.maxX - cs.width - 12)
        y = min(max(y, vf.minY + 12), vf.maxY - cs.height - 12)
        chat.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Nút đỏ: ẩn cửa sổ thay vì đóng hẳn (bong bóng vẫn còn để mở lại).
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
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
