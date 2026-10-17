import Cocoa

// ============================================================================
// Messenger Mini — floating chat-heads panel for macOS
//
// - Vertical avatar panel docked to the right screen edge (draggable)
// - Click an avatar -> floating chat window with that conversation
// - Conversations are configured by the user in ~/.messenger-mini/chats.json
//   (message content is STATIC until a live Messenger data source is wired up)
// - Clicking anything that needs the real Messenger opens the thread on
//   messenger.com in the default browser (user is already logged in there)
// ============================================================================

// MARK: - Model

struct ChatMessage: Codable {
    var from: String          // "me" | "them"
    var text: String
    var seen: Bool = false    // "me" only: show blue seen checkmarks under the bubble
    var reaction: String?     // optional emoji reaction shown under the bubble
}

struct ChatConfig: Codable {
    var name: String
    var avatar: String?       // local path (~/... ok) or https URL; empty -> initial letter
    var url: String           // e.g. https://www.messenger.com/t/123456
    var unread: Int = 0
    var preview: String?      // static subtitle shown under the name
    var messages: [ChatMessage] = []
}

struct AppConfig: Codable {
    var chats: [ChatConfig] = []
}

// MARK: - Config store (~/.messenger-mini/chats.json, watched for changes)

final class ConfigStore {
    static let shared = ConfigStore()

    let folder: URL
    let file: URL
    var config = AppConfig()
    var onChange: (() -> Void)?

    private var watcher: DispatchSourceFileSystemObject?

    private init() {
        folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".messenger-mini", isDirectory: true)
        file = folder.appendingPathComponent("chats.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            writeSample()
        }
        reload()
        startWatching()
    }

    func openFolder() {
        NSWorkspace.shared.open(folder)
    }

    func reload() {
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        }
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }

    private func writeSample() {
        let sample = AppConfig(chats: [
            ChatConfig(
                name: "Mèo Cam",
                avatar: "",
                url: "https://www.messenger.com/",
                unread: 2,
                preview: "Chà",
                messages: [
                    ChatMessage(from: "them", text: "Chà"),
                    ChatMessage(from: "them", text: "Messenger nay có tính năng mới nhỉ"),
                    ChatMessage(from: "them", text: "Tiện thật đó"),
                    ChatMessage(from: "me", text: "Quá ngon luôn ấy chứ"),
                    ChatMessage(from: "me", text: "Hiện tại xài thấy khá là oke nha", seen: true, reaction: "😃"),
                ]
            ),
            ChatConfig(
                name: "Nhóm lớp",
                avatar: "",
                url: "https://www.messenger.com/",
                unread: 0,
                preview: "Hẹn cuối tuần nhé",
                messages: [
                    ChatMessage(from: "them", text: "Cuối tuần này mọi người rảnh không?"),
                    ChatMessage(from: "me", text: "Tôi rảnh chiều thứ 7 nha"),
                ]
            ),
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(sample) {
            try? data.write(to: file)
        }
    }

    private func startWatching() {
        let fd = open(file.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.reload() }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }
}

// MARK: - Avatar image loading (local file or https, in-memory cache)

final class AvatarLoader {
    static let shared = AvatarLoader()
    private let cache = NSCache<NSString, NSImage>()

    /// Center-crops an image to a square so circular avatars get true "cover" behavior.
    private func squareCropped(_ image: NSImage) -> NSImage {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let side = min(cg.width, cg.height)
        guard side > 0 else { return image }
        let rect = CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: side, height: side))
    }

    func load(_ spec: String?, completion: @escaping (NSImage?) -> Void) {
        guard let spec = spec, !spec.isEmpty else { completion(nil); return }
        if let hit = cache.object(forKey: spec as NSString) { completion(hit); return }

        if spec.hasPrefix("http://") || spec.hasPrefix("https://") {
            guard let url = URL(string: spec) else { completion(nil); return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                var image: NSImage?
                if let data = data, let img = NSImage(data: data) {
                    let square = self?.squareCropped(img) ?? img
                    image = square
                    self?.cache.setObject(square, forKey: spec as NSString)
                }
                DispatchQueue.main.async { completion(image) }
            }.resume()
        } else {
            let path = (spec as NSString).expandingTildeInPath
            var image: NSImage?
            if let img = NSImage(contentsOfFile: path) {
                let square = squareCropped(img)
                image = square
                cache.setObject(square, forKey: spec as NSString)
            }
            completion(image)
        }
    }
}

// MARK: - Small red unread badge

final class BadgeView: NSView {
    var count: Int = 0 {
        didSet { isHidden = count <= 0; needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard count > 0 else { return }
        let d = min(bounds.width, bounds.height)
        let rect = NSRect(x: bounds.maxX - d, y: bounds.maxY - d, width: d, height: d)
        NSBezierPath(ovalIn: rect).fill(with: .systemRed)
        let text = count > 99 ? "99+" : "\(count)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(
            at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attrs
        )
    }
}

extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}

// MARK: - Circular clickable avatar

final class AvatarView: NSView {
    var onClick: (() -> Void)?

    init(diameter: CGFloat, name: String, avatarSpec: String?, unread: Int, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: diameter).isActive = true
        heightAnchor.constraint(equalToConstant: diameter).isActive = true

        let circle = NSView(frame: bounds)
        circle.wantsLayer = true
        circle.layer?.cornerRadius = diameter / 2
        circle.layer?.masksToBounds = true
        circle.layer?.backgroundColor = NSColor.systemGray.cgColor
        circle.autoresizingMask = [.width, .height]
        addSubview(circle)

        let imageView = NSImageView(frame: circle.bounds)
        imageView.imageScaling = .scaleAxesIndependently // image is pre-cropped to a square
        imageView.autoresizingMask = [.width, .height]
        circle.addSubview(imageView)

        let initial = name.first.map { String($0).uppercased() } ?? "?"
        let label = NSTextField(labelWithString: initial)
        label.font = NSFont.systemFont(ofSize: diameter * 0.38, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.frame = circle.bounds
        label.autoresizingMask = [.width, .height]
        circle.addSubview(label)

        AvatarLoader.shared.load(avatarSpec) { img in
            guard let img = img else { return }
            imageView.image = img
            label.isHidden = true
        }

        let badge = BadgeView(frame: NSRect(x: diameter - 20, y: diameter - 22, width: 20, height: 20))
        badge.count = unread
        badge.autoresizingMask = [.minXMargin, .maxYMargin]
        addSubview(badge)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func mouseDown(with event: NSEvent) { onClick?() }

    // Route clicks anywhere inside the avatar (label, image, badge subviews)
    // to this view, otherwise subviews swallow the click and onClick never fires.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) != nil else { return nil }
        return self
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

// MARK: - Deterministic window backgrounds (do not rely on vibrancy materials)

/// Dark translucent rounded bar for the avatar panel (matches the target UI).
final class PanelBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 20, yRadius: 20)
        NSColor(white: 0.16, alpha: 0.84).setFill()
        path.fill()
        NSColor(white: 1.0, alpha: 0.14).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

/// Light rounded background for the chat window.
final class ChatBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16)
        NSColor(white: 1.0, alpha: 0.97).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}

// MARK: - Drag handle (pill) for moving the panel

final class DragView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let w: CGFloat = 36, h: CGFloat = 5
        let r = NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
        NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2).fill(with: .tertiaryLabelColor)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let w = window else { return }
        var o = w.frame.origin
        o.x += event.deltaX
        o.y -= event.deltaY
        w.setFrameOrigin(o)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

// MARK: - Floating avatar panel

final class PanelController: NSObject {
    static var lastFrame: NSRect = .zero

    private let window: NSWindow
    private let avatarStack = NSStackView()
    private var collapsed = false
    private var popups: [String: NSWindow] = [:]
    private let panelWidth: CGFloat = 76
    private let originKey = "MessengerMiniPanelOrigin"

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let bg = PanelBackgroundView(frame: window.contentView!.bounds)
        bg.autoresizingMask = [.width, .height]
        window.contentView = bg

        super.init()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .centerX
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10),
            root.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])

        let handle = DragView()
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.heightAnchor.constraint(equalToConstant: 22).isActive = true
        handle.widthAnchor.constraint(equalToConstant: panelWidth - 16).isActive = true
        handle.toolTip = "Kéo để di chuyển"
        root.addArrangedSubview(handle)

        avatarStack.orientation = .vertical
        avatarStack.alignment = .centerX
        avatarStack.spacing = 10
        avatarStack.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(avatarStack)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 6
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.addArrangedSubview(makeIconButton(symbol: "message.circle.fill", tint: .systemBlue, tip: "Mở Messenger", action: #selector(openMessenger)))
        buttons.addArrangedSubview(makeIconButton(symbol: "square.and.pencil", tint: .labelColor, tip: "Tin nhắn mới", action: #selector(composeNew)))
        buttons.addArrangedSubview(makeIconButton(symbol: "ellipsis", tint: .secondaryLabelColor, tip: "Thêm", action: #selector(showMenu)))
        root.addArrangedSubview(buttons)

        ConfigStore.shared.onChange = { [weak self] in self?.rebuild() }
        rebuild()
        restoreOrigin()
        updatePreviewPopups()
        NotificationCenter.default.addObserver(
            self, selector: #selector(saveOrigin),
            name: NSWindow.didMoveNotification, object: window
        )
        window.orderFront(nil)
        Self.lastFrame = window.frame
    }

    private func makeIconButton(symbol: String, tint: NSColor, tip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage()
        let b = NSButton(image: image, target: self, action: action)
        b.isBordered = false
        b.contentTintColor = tint
        b.toolTip = tip
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 40).isActive = true
        b.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return b
    }

    private func rebuild() {
        let chats = ConfigStore.shared.config.chats
        for v in avatarStack.arrangedSubviews {
            avatarStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        if !collapsed {
            for chat in chats {
                let av = AvatarView(diameter: 54, name: chat.name, avatarSpec: chat.avatar, unread: chat.unread) {
                    ChatWindowController.toggle(chat)
                }
                av.toolTip = chat.name
                avatarStack.addArrangedSubview(av)
            }
        }
        avatarStack.isHidden = collapsed || chats.isEmpty
        layoutWindow()
        updatePreviewPopups()
    }

    private func layoutWindow() {
        let chats = ConfigStore.shared.config.chats
        let n = (collapsed || chats.isEmpty) ? 0 : chats.count
        var h: CGFloat = 10 + 22 + 8            // top + handle + spacing
        if n > 0 { h += CGFloat(n) * 54 + CGFloat(n - 1) * 10 + 8 }
        h += 40 + 10                             // buttons + bottom
        let old = window.frame
        let dy = h - old.height
        window.setFrame(NSRect(x: old.origin.x, y: old.origin.y - dy, width: panelWidth, height: h), display: true)
        Self.lastFrame = window.frame
    }

    private func restoreOrigin() {
        if let s = UserDefaults.standard.string(forKey: originKey) {
            let parts = s.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                var f = window.frame
                f.origin = NSPoint(x: parts[0], y: parts[1])
                window.setFrame(f, display: false)
                return
            }
        }
        // First launch: dock to the right edge, vertically centered
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var f = window.frame
        f.origin = NSPoint(x: screen.maxX - f.width - 12, y: screen.midY - f.height / 2)
        window.setFrame(f, display: false)
    }

    @objc private func saveOrigin() {
        let o = window.frame.origin
        UserDefaults.standard.set("\(o.x),\(o.y)", forKey: originKey)
        Self.lastFrame = window.frame
        updatePreviewPopups()
    }

    /// Floating ":)))" preview bubbles for chats with unread messages,
    /// parked to the left of their avatar (like image 1).
    private func updatePreviewPopups() {
        for w in popups.values { w.orderOut(nil) }
        popups.removeAll()
        guard !collapsed else { return }
        window.layoutIfNeeded()

        let chats = ConfigStore.shared.config.chats
        let rows = avatarStack.arrangedSubviews
        for (i, chat) in chats.enumerated() {
            guard chat.unread > 0,
                  let preview = chat.preview, !preview.isEmpty,
                  i < rows.count,
                  let row = rows[i].superview else { continue }
            let frameInWindow = row.convert(rows[i].frame, to: nil)
            let frameOnScreen = window.convertToScreen(frameInWindow)

            let bubble = PreviewBubble(text: preview) { ChatWindowController.toggle(chat) }
            let size = bubble.contentSize
            let pw = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
            pw.level = .floating
            pw.isOpaque = false
            pw.backgroundColor = .clear
            pw.hasShadow = false
            pw.collectionBehavior = [.canJoinAllSpaces, .stationary]
            bubble.frame = NSRect(origin: .zero, size: size)
            bubble.autoresizingMask = [.width, .height]
            pw.contentView = bubble
            pw.setFrameOrigin(NSPoint(x: frameOnScreen.minX - size.width - 4,
                                      y: frameOnScreen.midY - size.height / 2))
            pw.orderFront(nil)
            popups[chat.name + "#" + chat.url] = pw
        }
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openMessenger() { openURL("https://www.messenger.com/") }

    @objc private func composeNew() { openURL("https://www.messenger.com/new") }

    @objc private func toggleCollapse() {
        collapsed.toggle()
        rebuild()
    }

    @objc private func reloadConfig() { ConfigStore.shared.reload() }

    @objc private func openConfigFolder() { ConfigStore.shared.openFolder() }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: collapsed ? "Mở rộng panel" : "Thu gọn panel",
                                action: #selector(toggleCollapse), keyEquivalent: "")
        toggle.target = self
        let reload = NSMenuItem(title: "Tải lại cấu hình", action: #selector(reloadConfig), keyEquivalent: "")
        reload.target = self
        let folder = NSMenuItem(title: "Mở thư mục cấu hình", action: #selector(openConfigFolder), keyEquivalent: "")
        folder.target = self
        let quitItem = NSMenuItem(title: "Thoát", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(toggle)
        menu.addItem(reload)
        menu.addItem(folder)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
}

// MARK: - Chat message bubble

final class BubbleView: NSView {
    private let mine: Bool

    init(text: String, mine: Bool) {
        self.mine = mine
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 14)
        label.textColor = mine ? .white : .labelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 238
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        (mine ? NSColor.systemBlue : NSColor.controlColor).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 17, yRadius: 17).fill()
    }
}

// MARK: - Message unit: bubble + optional reaction + seen checkmarks

final class MessageUnitView: NSView {
    init(message: ChatMessage) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let mine = message.from == "me"

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = mine ? .trailing : .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        stack.addArrangedSubview(BubbleView(text: message.text, mine: mine))

        if let reaction = message.reaction, !reaction.isEmpty {
            let r = NSTextField(labelWithString: reaction)
            r.font = NSFont.systemFont(ofSize: 15)
            stack.addArrangedSubview(r)
        }

        if mine && message.seen {
            let s = NSTextField(labelWithString: "✓✓")
            s.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            s.textColor = .systemBlue
            stack.addArrangedSubview(s)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Floating chat window (one per conversation)

final class ChatWindowController: NSObject {
    private static var open: [String: ChatWindowController] = [:]

    private static func key(for chat: ChatConfig) -> String {
        chat.name + "#" + chat.url
    }

    static func toggle(_ chat: ChatConfig) {
        let k = key(for: chat)
        if let existing = open[k] {
            existing.window.close()
            return
        }
        let controller = ChatWindowController(chat: chat)
        open[k] = controller
        controller.window.makeKeyAndOrderFront(nil)
    }

    let window: NSWindow
    private let chat: ChatConfig

    private init(chat: ChatConfig) {
        self.chat = chat
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 540),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let bg = ChatBackgroundView(frame: window.contentView!.bounds)
        bg.autoresizingMask = [.width, .height]
        window.contentView = bg

        super.init()
        build(in: bg)
        placeNextToPanel()

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification, object: window
        )
    }

    @objc private func windowClosed() {
        Self.open.removeValue(forKey: Self.key(for: chat))
    }

    private func openThreadURL() {
        let target = chat.url.isEmpty ? "https://www.messenger.com/" : chat.url
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
    }

    private func placeNextToPanel() {
        let panel = PanelController.lastFrame
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var f = window.frame
        if panel.width > 0 {
            f.origin = NSPoint(x: panel.minX - f.width - 12, y: panel.minY - 60)
        } else {
            f.origin = NSPoint(x: screen.maxX - f.width - 100, y: screen.midY - f.height / 2)
        }
        // Clamp inside the visible screen
        f.origin.x = max(screen.minX + 8, min(f.origin.x, screen.maxX - f.width - 8))
        f.origin.y = max(screen.minY + 8, min(f.origin.y, screen.maxY - f.height - 8))
        window.setFrame(f, display: false)
    }

    private func headerButton(symbol: String, tint: NSColor, tip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage()
        let b = NSButton(image: image, target: self, action: action)
        b.isBordered = false
        b.contentTintColor = tint
        b.toolTip = tip
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 30).isActive = true
        b.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return b
    }

    private func build(in bg: NSView) {
        // ---- Header ----
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 64).isActive = true
        bg.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: bg.topAnchor),
            header.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        ])

        let avatar = AvatarView(diameter: 40, name: chat.name, avatarSpec: chat.avatar, unread: 0) { [weak self] in
            self?.openThread()
        }
        header.addSubview(avatar)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            avatar.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])

        let nameLabel = NSTextField(labelWithString: chat.name)
        nameLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(nameLabel)

        let subLabel = NSTextField(labelWithString: chat.preview ?? "Bấm để mở trên Messenger")
        subLabel.font = NSFont.systemFont(ofSize: 12)
        subLabel.textColor = .secondaryLabelColor
        subLabel.lineBreakMode = .byTruncatingTail
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subLabel)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 14),
            subLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            subLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -110),
        ])

        let headerButtons = NSStackView()
        headerButtons.orientation = .horizontal
        headerButtons.spacing = 2
        headerButtons.translatesAutoresizingMaskIntoConstraints = false
        headerButtons.addArrangedSubview(headerButton(symbol: "phone.fill", tint: .systemPurple, tip: "Gọi (mở Messenger)", action: #selector(openThread)))
        headerButtons.addArrangedSubview(headerButton(symbol: "video.fill", tint: .systemPurple, tip: "Gọi video (mở Messenger)", action: #selector(openThread)))
        headerButtons.addArrangedSubview(headerButton(symbol: "xmark", tint: .secondaryLabelColor, tip: "Đóng", action: #selector(closeWindow)))
        header.addSubview(headerButtons)
        NSLayoutConstraint.activate([
            headerButtons.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -8),
            headerButtons.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        bg.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: header.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
        ])

        // ---- Messages ----
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        bg.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        ])

        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 2
        list.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = list
        NSLayoutConstraint.activate([
            list.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            list.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 4),
            list.bottomAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.bottomAnchor, constant: -4),
        ])

        var lastRow: NSView?
        for msg in chat.messages {
            let row = NSView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
            let mine = msg.from == "me"
            let unit = MessageUnitView(message: msg)
            row.addSubview(unit)
            NSLayoutConstraint.activate([
                unit.topAnchor.constraint(equalTo: row.topAnchor, constant: 3),
                unit.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -3),
                unit.widthAnchor.constraint(lessThanOrEqualToConstant: 270),
            ])
            if mine {
                unit.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12).isActive = true
            } else {
                unit.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12).isActive = true
            }
            list.addArrangedSubview(row)
            lastRow = row
        }

        // ---- Input bar ----
        let inputBar = NSView()
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.heightAnchor.constraint(equalToConstant: 56).isActive = true
        bg.addSubview(inputBar)
        NSLayoutConstraint.activate([
            inputBar.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4),
            inputBar.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
        ])

        let plus = headerButton(symbol: "plus.circle.fill", tint: .systemBlue, tip: "Mở trên Messenger", action: #selector(openThread))
        plus.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(plus)
        NSLayoutConstraint.activate([
            plus.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 10),
            plus.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
        ])

        let input = NSTextField()
        input.placeholderString = "Nhập tin nhắn... (Enter để mở trên Messenger)"
        input.bezelStyle = .roundedBezel
        input.focusRingType = .none
        input.font = NSFont.systemFont(ofSize: 14)
        input.target = self
        input.action = #selector(openThread)
        input.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(input)

        let emoji = headerButton(symbol: "face.smiling", tint: .systemBlue, tip: "Mở trên Messenger", action: #selector(openThread))
        let like = headerButton(symbol: "hand.thumbsup.fill", tint: .systemBlue, tip: "Mở trên Messenger", action: #selector(openThread))
        inputBar.addSubview(emoji)
        inputBar.addSubview(like)
        emoji.translatesAutoresizingMaskIntoConstraints = false
        like.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            input.leadingAnchor.constraint(equalTo: plus.trailingAnchor, constant: 8),
            input.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            input.heightAnchor.constraint(equalToConstant: 34),
            emoji.leadingAnchor.constraint(equalTo: input.trailingAnchor, constant: 6),
            emoji.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            like.leadingAnchor.constraint(equalTo: emoji.trailingAnchor, constant: 2),
            like.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            like.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -8),
        ])

        // Scroll to the latest message
        bg.layoutSubtreeIfNeeded()
        if let last = lastRow {
            scrollView.contentView.scrollToVisible(last.frame)
        }
    }

    @objc private func openThread() {
        openThreadURL()
    }

    @objc private func closeWindow() {
        window.close()
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon
        panel = PanelController()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// MARK: - Message preview popup bubble (the ":)))" bubble next to an avatar)

final class PreviewBubble: NSView {
    private let onClick: (() -> Void)?
    private let font = NSFont.systemFont(ofSize: 13)
    private let hPad: CGFloat = 12
    private let vPad: CGFloat = 8
    private let tailWidth: CGFloat = 8
    private let maxTextWidth: CGFloat = 170
    let contentSize: NSSize

    init(text: String, onClick: (() -> Void)? = nil) {
        self.onClick = onClick

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .labelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isBordered = false
        label.backgroundColor = .clear
        // Measure with AppKit's own layout (handles diacritics correctly),
        // then clamp to a single line when it fits.
        label.preferredMaxLayoutWidth = 1000
        let naturalW = ceil(label.intrinsicContentSize.width)
        let w = min(naturalW, maxTextWidth)
        label.preferredMaxLayoutWidth = w
        let h = ceil(label.intrinsicContentSize.height)
        contentSize = NSSize(width: w + hPad * 2 + tailWidth, height: h + vPad * 2)

        super.init(frame: NSRect(origin: .zero, size: contentSize))
        wantsLayer = true
        label.frame = NSRect(x: hPad, y: vPad, width: w, height: h)
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSColor.textBackgroundColor
        let bodyW = bounds.width - tailWidth
        let body = NSRect(x: 0, y: 0, width: bodyW, height: bounds.height)
        NSBezierPath(roundedRect: body, xRadius: 11, yRadius: 11).fill(with: bg)

        // Little tail pointing right, toward the avatar
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bodyW - 1, y: bounds.midY - 6))
        tail.line(to: NSPoint(x: bounds.width, y: bounds.midY))
        tail.line(to: NSPoint(x: bodyW - 1, y: bounds.midY + 6))
        tail.close()
        tail.fill(with: bg)

        NSBezierPath(roundedRect: body, xRadius: 11, yRadius: 11).stroke(with: .separatorColor)
    }

    override func mouseDown(with event: NSEvent) { onClick?() }

    // Same as AvatarView: make the whole bubble (including its text label) clickable.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) != nil else { return nil }
        return self
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

extension NSBezierPath {
    func stroke(with color: NSColor) {
        color.setStroke()
        lineWidth = 0.5
        stroke()
    }
}
