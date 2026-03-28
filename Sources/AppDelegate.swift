import Cocoa
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var skinWindow: NSWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        buildMenu()
        ActionLogger.shared.log("WMZ Renderer started")
        openFile(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit WMZ Renderer",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        let fileItem = NSMenuItem(); menu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        let openItem = fileMenu.addItem(withTitle: "Open WMZ…",
                                        action: #selector(openFile(_:)),
                                        keyEquivalent: "o")
        openItem.target = self

        let viewItem = NSMenuItem(); menu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        let toggleItem = viewMenu.addItem(withTitle: "Toggle Play / Configure",
                                          action: #selector(toggleMode(_:)),
                                          keyEquivalent: "d")
        toggleItem.target = self

        NSApp.mainMenu = menu
    }

    // MARK: - File Open

    @objc func openFile(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title   = "Open WMZ Skin"
        panel.message = "Select a Windows Media Player .wmz skin file"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let t = UTType(filenameExtension: "wmz") { panel.allowedContentTypes = [t] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadSkin(from: url)
    }

    private func loadSkin(from url: URL) {
        ActionLogger.shared.log("Opening: \(url.lastPathComponent)")
        do {
            let dir    = try WMZLoader.extract(url)
            let wmsURL = try WMZLoader.findWMS(in: dir)
            ActionLogger.shared.log("Parsing: \(wmsURL.lastPathComponent)")

            guard let skin = WMSParser().parse(contentsOf: wmsURL) else {
                throw NSError(domain: "WMZ", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "XML parse failed"])
            }
            guard let view = skin.primaryView else {
                throw NSError(domain: "WMZ", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "No usable <view> in skin"])
            }

            ActionLogger.shared.log(
                "Found \(skin.views.count) view(s); using '\(view.id)' (\(view.width)×\(view.height))"
            )

            displaySkin(skin, resourceDir: dir)

        } catch {
            ActionLogger.shared.log("ERROR: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText     = "Failed to load skin"
            alert.informativeText = error.localizedDescription
            alert.alertStyle      = .warning
            alert.runModal()
        }
    }

    private func displaySkin(_ skin: WMSSkin, resourceDir: URL) {
        skinWindow?.close()

        let skinView = SkinView(skin: skin, resourceDir: resourceDir)

        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: skinView.frame.size),
            styleMask:   [.titled, .closable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        win.title = "WMZ Renderer"
        win.isOpaque = false
        win.backgroundColor = .clear
        win.contentView = skinView
        win.center()
        win.makeKeyAndOrderFront(nil)
        skinWindow = win
    }

    // MARK: - Mode Toggle (Cmd+D)

    @objc private func toggleMode(_ sender: Any?) {
        guard let win      = skinWindow,
              let skinView = win.contentView as? SkinView else { return }
        let nowConfigure = skinView.toggleMode()
        win.title = nowConfigure ? "WMZ Renderer — Configure" : "WMZ Renderer"
    }
}
