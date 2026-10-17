import AppKit

// ============================================================================
// iMessage Bubble — bong bóng chat mini luôn nổi trên màn hình (AppKit thuần).
//
// - Không SwiftUI, không NSHostingView: chỉ AppKit, đã chứng minh hiển thị
//   được trên macOS (pattern main.swift top-level như project widget cũ).
// - Bubble tròn 68pt, kéo thả tự do, nhớ vị trí, bấm để mở/đóng cửa sổ chat.
// - Chuột phải vào bubble: menu "Mở/đóng chat" và "Thoát".
// - Không mạng, không đăng nhập, dữ liệu giả lập trong RAM.
// ============================================================================

// MARK: - Cấu hình

private let bubbleDiameter: CGFloat = 68
private let bubbleBlue = NSColor(red: 0.0, green: 0.52, blue: 1.0, alpha: 1.0) // #0084FF
private let positionKey = "iMessageBubble.origin"
private let dragThreshold: CGFloat = 4

// MARK: - BubbleView: hình tròn xanh + icon tin nhắn, kéo thả + bấm

/// NSView tròn: kéo để di chuyển, bấm (không kéo) để mở/đóng chat,
/// chuột phải để mở menu.
final class BubbleView: NSView {

    var onTap: (() -> Void)?
    var onRightClick: ((NSEvent, NSView) -> Void)?

    private var downPoint: NSPoint?
    private var dragAnchor: NSPoint?
    private var dragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = bubbleBlue.cgColor
        layer?.cornerRadius = frameRect.width / 2

        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: "message.fill",
                             accessibilityDescription: "Tin nhắn") {
            img.isTemplate = true
            icon.image = img
        }
        icon.contentTintColor = .white
        let inset: CGFloat = 20
        icon.frame = bounds.insetBy(dx: inset, dy: inset)
        icon.autoresizingMask = [.width, .height]
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)

        toolTip = "iMessage Bubble — bấm để mở chat, chuột phải để thêm tùy chọn"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
        dragAnchor = window?.frame.origin
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = downPoint, let anchor = dragAnchor,
              let window = window else { return }
        let cur = event.locationInWindow
        let dx = cur.x - down.x
        let dy = cur.y - down.y
        if !dragging {
            guard hypot(dx, dy) >= dragThreshold else { return }
            dragging = true
        }
        window.setFrameOrigin(NSPoint(x: anchor.x + dx, y: anchor.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        let wasDragging = dragging
        downPoint = nil
        dragAnchor = nil
        dragging = false
        savePosition()
        if !wasDragging {
            onTap?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event, self)
    }

    private func savePosition() {
        guard let window = window else { return }
        let o = window.frame.origin
        UserDefaults.standard.set("\(o.x),\(o.y)", forKey: positionKey)
    }
}

// MARK: - BubbleWindow: NSPanel nổi chứa bubble

final class BubbleWindow: NSPanel {

    private var bubbleView: BubbleView!

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: bubbleDiameter, height: bubbleDiameter),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        let bv = BubbleView(frame: NSRect(x: 0, y: 0,
                                          width: bubbleDiameter, height: bubbleDiameter))
        bv.autoresizingMask = [.width, .height]
        bubbleView = bv
        contentView = bv
    }

    var onTap: (() -> Void)? {
        get { bubbleView.onTap }
        set { bubbleView.onTap = newValue }
    }

    var onRightClick: ((NSEvent, NSView) -> Void)? {
        get { bubbleView.onRightClick }
        set { bubbleView.onRightClick = newValue }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Hiện bubble: khôi phục vị trí cũ, hoặc góc dưới-phải nếu chưa có.
    func showBubble() {
        let origin = keepOnScreen(restoredOrigin() ?? defaultOrigin())
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    private func defaultOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let v = screen.visibleFrame
        return NSPoint(x: v.maxX - bubbleDiameter - 24, y: v.minY + 24)
    }

    private func restoredOrigin() -> NSPoint? {
        guard let s = UserDefaults.standard.string(forKey: positionKey) else { return nil }
        let parts = s.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return NSPoint(x: parts[0], y: parts[1])
    }

    private func keepOnScreen(_ origin: NSPoint) -> NSPoint {
        guard let screen = NSScreen.main else { return origin }
        let v = screen.visibleFrame
        let m: CGFloat = 8
        return NSPoint(
            x: min(max(origin.x, v.minX + m), v.maxX - bubbleDiameter - m),
            y: min(max(origin.y, v.minY + m), v.maxY - bubbleDiameter - m)
        )
    }
}

// MARK: - ChatWindow: cửa sổ chat tối giản (AppKit thuần)

/// Panel chat đơn giản: log tin nhắn + ô nhập + nút Gửi.
/// Dữ liệu giả lập trong RAM, có trả lời tự động cho vui.
final class ChatWindow: NSPanel {

    private let textView = NSTextView()
    private let input = NSTextField()
    private var replyIndex = 0
    private let autoReplies = [
        "Ok bạn ơi! 👍",
        "Để mình xem lịch đã nhé 😄",
        "Chốt đơn! ✅",
        "Haha chuẩn luôn 😂",
    ]

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "iMessage Mini"
        minSize = NSSize(width: 300, height: 400)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        let cr = contentLayoutRect
        let inputH: CGFloat = 52

        // Vùng log tin nhắn.
        let scroll = NSScrollView(frame: NSRect(x: 0, y: inputH,
                                                width: cr.width, height: cr.height - inputH))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView

        // Thanh nhập phía dưới.
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: cr.width, height: inputH))
        bar.autoresizingMask = [.width, .maxYMargin]

        input.frame = NSRect(x: 12, y: 10, width: bar.frame.width - 24 - 76, height: 32)
        input.autoresizingMask = [.width]
        input.placeholderString = "Nhắn tin..."
        input.target = self
        input.action = #selector(sendMessage)

        let sendButton = NSButton(frame: NSRect(x: bar.frame.width - 70, y: 10,
                                                width: 58, height: 32))
        sendButton.title = "Gửi"
        sendButton.bezelStyle = .rounded
        sendButton.target = self
        sendButton.action = #selector(sendMessage)
        sendButton.autoresizingMask = [.minXMargin]
        bar.addSubview(input)
        bar.addSubview(sendButton)

        let root = NSView(frame: cr)
        root.autoresizingMask = [.width, .height]
        root.addSubview(scroll)
        root.addSubview(bar)
        contentView = root

        // Tin nhắn mẫu.
        appendMessage(sender: "An", text: "Ê, cuối tuần đi Đà Lạt không mọi người?", own: false)
        appendMessage(sender: "Bình", text: "Tui ok nha! 🎉", own: false)
        appendMessage(sender: "Bạn", text: "Chốt! Tui book homestay cho.", own: true)
    }

    /// Focus vào ô nhập khi mở chat.
    func focusInput() {
        makeFirstResponder(input)
    }

    @objc private func sendMessage() {
        let t = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        input.stringValue = ""
        appendMessage(sender: "Bạn", text: t, own: true)
        let reply = autoReplies[replyIndex % autoReplies.count]
        replyIndex += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.appendMessage(sender: "An", text: reply, own: false)
        }
    }

    private func appendMessage(sender: String, text: String, own: Bool) {
        let para = NSMutableParagraphStyle()
        para.alignment = own ? .right : .left
        para.paragraphSpacing = 2

        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para,
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ]
        let full = NSMutableAttributedString()
        full.append(NSAttributedString(string: sender + "\n", attributes: nameAttrs))
        full.append(NSAttributedString(string: text + "\n\n", attributes: bodyAttrs))
        textView.textStorage?.append(full)
        textView.scrollToEndOfDocument(nil)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var bubble: BubbleWindow?
    private var chat: ChatWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenu()

        let b = BubbleWindow()
        b.onTap = { [weak self] in self?.toggleChat() }
        b.onRightClick = { [weak self] event, view in self?.showBubbleMenu(event: event, view: view) }
        bubble = b

        chat = ChatWindow()

        b.showBubble()
    }

    /// Bấm bubble: mở/đóng cửa sổ chat, đặt cạnh bubble.
    func toggleChat() {
        guard let chat = chat, let bubble = bubble else { return }
        if chat.isVisible {
            chat.orderOut(nil)
        } else {
            var f = chat.frame
            f.origin = NSPoint(x: bubble.frame.minX - f.width - 16,
                               y: bubble.frame.minY - 60)
            chat.setFrameOrigin(keepChatOnScreen(f.origin, size: f.size))
            chat.makeKeyAndOrderFront(nil)
            chat.focusInput()
        }
    }

    private func keepChatOnScreen(_ origin: NSPoint, size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return origin }
        let v = screen.visibleFrame
        let m: CGFloat = 8
        return NSPoint(
            x: min(max(origin.x, v.minX + m), v.maxX - size.width - m),
            y: min(max(origin.y, v.minY + m), v.maxY - size.height - m)
        )
    }

    @objc private func toggleChatMenu(_ sender: Any?) {
        toggleChat()
    }

    private func showBubbleMenu(event: NSEvent, view: NSView) {
        let menu = NSMenu()
        let chatItem = NSMenuItem(title: "Mở/đóng chat",
                                  action: #selector(toggleChatMenu(_:)),
                                  keyEquivalent: "")
        chatItem.target = self
        menu.addItem(chatItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Thoát iMessage Bubble",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    private func installMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        let quitItem = NSMenuItem(title: "Thoát iMessage Bubble",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        appMenu.addItem(quitItem)
        NSApp.mainMenu = mainMenu
    }
}

// MARK: - Điểm vào ứng dụng (pattern main.swift top-level, như project widget cũ)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
