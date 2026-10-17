import AppKit

/// Điểm vào ứng dụng (`@main` thay cho main.swift).
///
/// - Không storyboard, không SwiftUI App lifecycle: toàn bộ cửa sổ do AppKit quản lý,
///   vì SwiftUI chưa kiểm soát được hành vi floating/non-activating của NSPanel.
/// - Activation policy `.accessory`: không hiện icon trên Dock, phù hợp app panel nổi.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[iMessageMini][DEBUG] applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        installMenu()

        let panel = FloatingPanel()
        self.panel = panel
        panel.showPanel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu tối thiểu (chỉ cần Quit với Cmd+Q)

    private func installMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "imessage-mini")
        appMenuItem.submenu = appMenu

        let quitItem = NSMenuItem(
            title: "Quit imessage-mini",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        NSApp.mainMenu = mainMenu
    }
}
