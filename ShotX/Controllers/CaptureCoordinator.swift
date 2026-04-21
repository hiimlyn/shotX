import AppKit

@MainActor
final class CaptureCoordinator {
    private let screenshotService: ScreenshotService
    private let clipboardService: ClipboardService
    private let permissionService: PermissionService
    private let previewWindowController: PreviewWindowController

    init(
        screenshotService: ScreenshotService,
        clipboardService: ClipboardService,
        permissionService: PermissionService,
        previewWindowController: PreviewWindowController
    ) {
        self.screenshotService = screenshotService
        self.clipboardService = clipboardService
        self.permissionService = permissionService
        self.previewWindowController = previewWindowController
    }

    func captureSelection() {
        permissionService.prepareForScreenCapture()

        Task {
            do {
                let image = try await screenshotService.captureSelection()
                present(image)
            } catch ScreenshotError.cancelled {
                return
            } catch {
                presentError(error)
            }
        }
    }

    func captureWindow() {
        permissionService.prepareForScreenCapture()

        Task {
            do {
                let image = try await screenshotService.capturePickedWindow()
                present(image)
            } catch ScreenshotError.cancelled {
                return
            } catch {
                presentError(error)
            }
        }
    }

    func captureFullScreen() {
        permissionService.prepareForScreenCapture()

        Task {
            do {
                let image = try await screenshotService.captureMainDisplay()
                present(image)
            } catch {
                presentError(error)
            }
        }
    }

    func openLastCapture() {
        guard previewWindowController.lastImage != nil else {
            presentError(ScreenshotError.noLastCapture)
            return
        }

        previewWindowController.openFullPreview()
    }

    func checkPermissions() {
        permissionService.showScreenRecordingGuidance()
    }

    private func present(_ image: NSImage) {
        clipboardService.copy(image)
        previewWindowController.show(image: image)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "ShotX could not capture the screenshot"
        alert.runModal()
    }
}
