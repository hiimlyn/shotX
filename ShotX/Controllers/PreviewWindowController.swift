import AppKit

@MainActor
final class PreviewWindowController: NSWindowController {
    static let compactPreviewSize = NSSize(width: 360, height: 238)
    static let compactPreviewMargin: CGFloat = 8

    // Width is the gap from the preview's right edge to the screen's right edge.
    // Height is the gap from the preview's top edge to the screen's top edge.
    static let compactPreviewStartOffset = NSSize(
        width: 16,
        height: 16
    )

    static let editorMaximumSize = NSSize(width: 1240, height: 760)
    static let editorScreenFill: CGFloat = 0.82

    let thumbnailImageView = NSImageView()
    let titleField = NSTextField(labelWithString: "Screenshot captured")
    let detailField = NSTextField(labelWithString: "Ready to preview or save")
    let canvasView = ScreenshotCanvasView()
    private let settingsService: SettingsService

    var editorWindow: NSWindow?
    var compactPreviewWasMoved = false
    private(set) var lastImage: NSImage?

    init(settingsService: SettingsService) {
        self.settingsService = settingsService

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.compactPreviewSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.setFixedContentSize(Self.compactPreviewSize)

        super.init(window: window)
        configureCompactPreview()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(image: NSImage) {
        lastImage = image
        thumbnailImageView.image = image
        canvasView.image = image
        detailField.stringValue = "Ready to preview or save"

        window?.setFixedContentSize(Self.compactPreviewSize)
        positionCompactWindow()
        showWindow(nil)
        window?.orderFrontRegardless()
    }

    func openFullPreview() {
        showEditor()
    }

    @objc func closeCompactPreview() {
        window?.orderOut(nil)
    }

    @objc func showEditor() {
        guard let image = lastImage else { return }

        canvasView.image = image
        let editorWindow = editorWindow ?? makeEditorWindow()
        editorWindow.setFrame(Self.editorFrame(), display: true)
        editorWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func saveOriginalImage() {
        guard let image = lastImage else { return }

        do {
            let url = try settingsService.nextCaptureURL()
            try Self.write(image: image, to: url)
            detailField.stringValue = "Saved: \(url.lastPathComponent)"
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc func saveStyledImage() {
        do {
            let url = try settingsService.nextCaptureURL()
            let image = canvasView.renderedImage()
            try Self.write(image: image, to: url)
            detailField.stringValue = "Saved styled: \(url.lastPathComponent)"
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc func sliderChanged(_ sender: NSSlider) {
        switch sender.tag {
        case 1:
            canvasView.padding = CGFloat(sender.doubleValue)
        case 2:
            canvasView.inset = CGFloat(sender.doubleValue)
        case 3:
            canvasView.borderRadius = CGFloat(sender.doubleValue)
        case 4:
            canvasView.shadowStrength = CGFloat(sender.doubleValue)
        default:
            break
        }
    }

    @objc func backgroundChanged(_ sender: NSButton) {
        canvasView.backgroundStyle = ScreenshotCanvasView.BackgroundStyle(rawValue: sender.tag) ?? .aurora
    }

    @objc func ratioChanged(_ sender: NSButton) {
        switch sender.tag {
        case 1:
            canvasView.aspectRatio = nil
        case 2:
            canvasView.aspectRatio = 4.0 / 3.0
        case 3:
            canvasView.aspectRatio = 3.0 / 2.0
        case 4:
            canvasView.aspectRatio = 16.0 / 9.0
        case 5:
            canvasView.aspectRatio = 1.0
        default:
            break
        }
    }

    private func positionCompactWindow() {
        guard let window else { return }

        let targetPoint = compactPreviewWasMoved || window.isVisible
            ? NSPoint(x: window.frame.midX, y: window.frame.midY)
            : NSEvent.mouseLocation
        let screen = Self.screen(containing: targetPoint) ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }

        let margin = Self.compactPreviewMargin
        let size = Self.compactPreviewSize
        if compactPreviewWasMoved {
            let frame = Self.clampedFrame(
                origin: window.frame.origin,
                size: size,
                visibleFrame: visibleFrame,
                margin: margin
            )
            window.setFixedContentSize(size)
            window.setFrame(frame, display: true, animate: false)
            return
        }

        let startOffset = Self.compactPreviewStartOffset
        let desiredX = visibleFrame.maxX - size.width - startOffset.width
        let desiredY = visibleFrame.maxY - size.height - startOffset.height
        let maxX = visibleFrame.maxX - size.width - margin
        let maxY = visibleFrame.maxY - size.height - margin
        let frame = NSRect(
            x: min(max(desiredX, visibleFrame.minX + margin), maxX),
            y: min(max(desiredY, visibleFrame.minY + margin), maxY),
            width: size.width,
            height: size.height
        )
        window.setFixedContentSize(size)
        window.setFrame(frame, display: true, animate: false)
    }

    private static func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }
    }

    private static func clampedFrame(origin: NSPoint, size: NSSize, visibleFrame: NSRect, margin: CGFloat) -> NSRect {
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - size.width - margin
        let minY = visibleFrame.minY + margin
        let maxY = visibleFrame.maxY - size.height - margin

        return NSRect(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY),
            width: size.width,
            height: size.height
        )
    }

    private static func editorFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(
            width: min(editorMaximumSize.width, visibleFrame.width * editorScreenFill),
            height: min(editorMaximumSize.height, visibleFrame.height * editorScreenFill)
        )
        return NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func write(image: NSImage, to url: URL) throws {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw ScreenshotError.imageEncodingFailed
        }

        try png.write(to: url, options: .atomic)
    }
}

private extension NSWindow {
    func setFixedContentSize(_ size: NSSize) {
        minSize = size
        maxSize = size
        contentMinSize = size
        contentMaxSize = size
        setContentSize(size)
    }
}
