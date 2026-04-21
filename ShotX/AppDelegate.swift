import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var captureCoordinator: CaptureCoordinator?
    private var settingsWindowController: SettingsWindowController?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let screenshotService = ScreenshotService()
        let clipboardService = ClipboardService()
        let permissionService = PermissionService()
        let settingsService = SettingsService()
        let previewWindowController = PreviewWindowController(settingsService: settingsService)
        let settingsWindowController = SettingsWindowController(settingsService: settingsService)
        let captureCoordinator = CaptureCoordinator(
            screenshotService: screenshotService,
            clipboardService: clipboardService,
            permissionService: permissionService,
            previewWindowController: previewWindowController
        )
        self.captureCoordinator = captureCoordinator
        self.settingsWindowController = settingsWindowController

        menuBarController = MenuBarController(
            captureSelection: { captureCoordinator.captureSelection() },
            captureWindow: { captureCoordinator.captureWindow() },
            captureFullScreen: { captureCoordinator.captureFullScreen() },
            openLastCapture: { captureCoordinator.openLastCapture() },
            openSettings: { settingsWindowController.show() },
            checkPermissions: { captureCoordinator.checkPermissions() }
        )

        hotkeyManager = HotkeyManager(
            captureSelection: { captureCoordinator.captureSelection() },
            captureFullScreen: { captureCoordinator.captureFullScreen() }
        )
        hotkeyManager?.start()
    }
}
