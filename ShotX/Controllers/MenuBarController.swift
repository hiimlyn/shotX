import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem

    init(
        captureSelection: @escaping () -> Void,
        captureWindow: @escaping () -> Void,
        captureFullScreen: @escaping () -> Void,
        openLastCapture: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        checkPermissions: @escaping () -> Void
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ShotX")
            button.toolTip = "ShotX"
        }

        let menu = NSMenu()
        let selectionItem = MenuItem(title: "Capture Selection", keyEquivalent: "s", action: captureSelection)
        selectionItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(selectionItem)
        menu.addItem(MenuItem(title: "Capture Window", keyEquivalent: "", action: captureWindow))
        menu.addItem(MenuItem(title: "Capture Full Screen", keyEquivalent: "", action: captureFullScreen))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(MenuItem(title: "Open Last Capture", keyEquivalent: "", action: openLastCapture))
        menu.addItem(MenuItem(title: "Settings...", keyEquivalent: ",", action: openSettings))
        menu.addItem(MenuItem(title: "Check Permissions", keyEquivalent: "", action: checkPermissions))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }
}

private final class MenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, action: @escaping () -> Void) {
        self.handler = action
        super.init(title: title, action: #selector(runHandler), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func runHandler() {
        handler()
    }
}
