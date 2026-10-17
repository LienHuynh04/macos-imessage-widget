//
//  main.swift
//  Messenger Mini — bong bóng nổi bọc Messenger web (AppKit thuần, không SwiftUI).
//
//  Cách hoạt động:
//   - Cửa sổ chat là một WKWebView mở https://www.messenger.com.
//   - Bạn TỰ đăng nhập bằng tay 1 lần ngay trong app; phiên đăng nhập được
//     macOS lưu trong cookie store của app (không qua tay ai khác).
//   - JavaScript inject vào trang đọc document.title ("(3) Messenger") để lấy
//     số tin chưa đọc, báo về native qua WKScriptMessageHandler → hiện badge
//     đỏ trên bong bóng.
//   - Bấm bong bóng: ẩn/hiện cửa sổ chat. Chuột phải: menu (đăng xuất, thoát).
//
//  Lưu ý trung thực:
//   - Đây là web Messenger chạy trong app của bạn, KHÔNG phải API chính thức.
//   - Nếu Meta đổi cấu trúc trang/tiêu đề, badge có thể đọc sai — cửa sổ chat
//     vẫn dùng bình thường.
//   - App cần mạng (mở messenger.com) và bạn phải tự đăng nhập được.

import AppKit
import WebKit

// MARK: - Hằng số

private enum Mini {
    static let bubbleDiameter: CGFloat = 68
    static let bubbleColor = NSColor(red: 0.0, green: 0.52, blue: 1.0, alpha: 1.0) // #0084FF
    static let chatURL = URL(string: "https://www.messenger.com")!
    static let originKey = "messengerMini.bubbleOrigin" // UserDefaults
    static let chatFrameKey = "NSWindow Frame MessengerMiniChat" // autosave của NSWindow
    static let dragThreshold: CGFloat = 4
}

/// JavaScript inject vào messenger.com: đọc số tin chưa đọc từ document.title.
/// Messenger web tự thêm "(N)" vào đầu title khi có tin chưa đọc, ví dụ "(3) Messenger".
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

// MARK: - Cầu JS → Native (wrapper weak, tránh retain-cycle)

/// WKUserContentController giữ handler rất lâu nên không được để nó giữ
/// AppDelegate (sẽ tạo chu trình giữ). Wrapper này chỉ giữ weak.
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

// MARK: - Bong bóng

private final class BubbleView: NSView {

    var unreadCount: Int = 0 { didSet { needsDisplay = true } }
    var onTap: (() -> Void)?
    var onToggleChat: (() -> Void)?
    var onLogout: (() -> Void)?
    var onQuit: (() -> Void)?

    private var pressPoint: NSPoint = .zero
    private var pressOrigin: NSPoint = .zero
    private var dragged = false

    // MARK: Vẽ

    override func draw(_ dirtyRect: NSRect) {
        // Hình tròn xanh
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        Mini.bubbleColor.setFill()
        circle.fill()

        // Icon message.fill trắng, căn giữa
        if let symbol = NSImage(systemSymbolName: "message.fill",
                                accessibilityDescription: "Messenger") {
            let iconSize = NSSize(width: 30, height: 30)
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

        // Badge đỏ: số tin chưa đọc, góc trên-phải
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

    // MARK: Kéo / bấm (phân biệt bằng ngưỡng 4pt)

    override func mouseDown(with event: NSEvent) {
        pressPoint = event.locationInWindow
        pressOrigin = window?.frame.origin ?? .zero
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let cur = event.locationInWindow
        let dx = cur.x - pressPoint.x
        let dy = cur.y - pressPoint.y
        if abs(dx) + abs(dy) > Mini.dragThreshold { dragged = true }
        win.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if !dragged { onTap?() }
        clampOnScreen()
        saveOrigin()
    }

    private func clampOnScreen() {
        guard let win = window, let screen = win.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        var o = win.frame.origin
        let s = win.frame.size
        // Cho phép tràn mép một chút kiểu chat-heads, nhưng luôn chừa 40pt để túm lại
        o.x = min(max(o.x, vf.minX - s.width + 40), vf.maxX - 40)
        o.y = min(max(o.y, vf.minY - s.height + 40), vf.maxY - 40)
        win.setFrameOrigin(o)
    }

    private func saveOrigin() {
        guard let o = window?.frame.origin else { return }
        UserDefaults.standard.set("\(o.x),\(o.y)", forKey: Mini.originKey)
    }

    // MARK: Menu chuột phải

    @objc private func menuToggleChat(_ sender: NSMenuItem) { onToggleChat?() }
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
        menu.addItem(item("Đăng xuất Messenger…", #selector(menuLogout)))
        menu.addItem(.separator())
        menu.addItem(item("Thoát", #selector(menuQuit)))
        menu.popUp(positioning: nil,
                   at: convert(event.locationInWindow, from: nil),
                   in: self)
    }
}

private final class BubbleWindow: NSPanel {

    let bubbleView = BubbleView()

    init() {
        let d = Mini.bubbleDiameter
        super.init(contentRect: NSRect(x: 0, y: 0, width: d, height: d),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        bubbleView.frame = NSRect(x: 0, y: 0, width: d, height: d)
        bubbleView.autoresizingMask = [.width, .height]
        contentView = bubbleView
        restoreOrigin()
    }

    private func restoreOrigin() {
        let d = Mini.bubbleDiameter
        var origin: NSPoint?
        if let s = UserDefaults.standard.string(forKey: Mini.originKey) {
            let parts = s.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { origin = NSPoint(x: parts[0], y: parts[1]) }
        }
        if origin == nil, let vf = NSScreen.main?.visibleFrame {
            origin = NSPoint(x: vf.maxX - d - 24, y: vf.minY + 24) // góc dưới-phải
        }
        setFrameOrigin(origin ?? .zero)
    }
}

// MARK: - Cửa sổ chat (WKWebView bọc messenger.com)

private final class ChatWindow: NSWindow {

    let webView: WKWebView

    init(scriptHandler: UnreadScriptHandler) {
        let config = WKWebViewConfiguration()
        // Cookie store persistent của hệ thống → đăng nhập 1 lần, nhớ mãi
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
        setFrameAutosaveName("MessengerMiniChat")
        webView.load(URLRequest(url: Mini.chatURL))
    }
}

// MARK: - AppDelegate

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var bubble: BubbleWindow!
    private var chat: ChatWindow!
    private let scriptHandler = UnreadScriptHandler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // không hiện Dock
        buildMenu()
        scriptHandler.target = self

        bubble = BubbleWindow()
        chat = ChatWindow(scriptHandler: scriptHandler)
        chat.delegate = self
        positionChatDefaultIfNeeded()

        let bv = bubble.bubbleView
        bv.onTap = { [weak self] in self?.toggleChat() }
        bv.onToggleChat = { [weak self] in self?.toggleChat() }
        bv.onLogout = { [weak self] in self?.logout() }
        bv.onQuit = { NSApp.terminate(nil) }

        bubble.orderFrontRegardless()
    }

    // MARK: Badge

    func setUnreadCount(_ count: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.bubble.bubbleView.unreadCount = count
        }
    }

    // MARK: Chat window

    private func toggleChat() {
        if chat.isVisible {
            chat.orderOut(nil)
        } else {
            chat.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
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

    /// Nút đỏ: ẩn cửa sổ thay vì đóng hẳn (bong bóng vẫn còn).
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    // MARK: Đăng xuất (xóa phiên đăng nhập trong app)

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

    // MARK: Menu (Cmd+Q)

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Thoát Messenger Mini",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
}

// MARK: - main (top-level, không @main)

let app = NSApplication.shared
let delegate = AppDelegate() // biến top-level: sống suốt vòng đời process
app.delegate = delegate
app.run()
