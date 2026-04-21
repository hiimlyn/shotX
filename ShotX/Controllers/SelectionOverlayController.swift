import AppKit

@MainActor
final class SelectionOverlayController: NSWindowController {
    private static var activeController: SelectionOverlayController?
    private var continuation: CheckedContinuation<CGRect, Error>?

    static func pickRect() async throws -> CGRect {
        try await withCheckedThrowingContinuation { continuation in
            let controller = SelectionOverlayController(continuation: continuation)
            activeController = controller
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private init(continuation: CheckedContinuation<CGRect, Error>) {
        self.continuation = continuation

        let screenFrame = NSScreen.screens
            .map(\.frame)
            .reduce(CGRect.null) { $0.union($1) }

        let window = SelectionOverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = false
        window.hasShadow = false

        super.init(window: window)

        let selectionView = SelectionOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        selectionView.onComplete = { [weak self] rect in
            self?.finish(with: rect)
        }
        selectionView.onCancel = { [weak self] in
            self?.cancel()
        }
        window.contentView = selectionView
        window.makeFirstResponder(selectionView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func finish(with localRect: CGRect) {
        guard let window else { return }
        let globalRect = window.convertToScreen(localRect).standardized

        close()
        continuation?.resume(returning: globalRect)
        continuation = nil
        Self.activeController = nil
    }

    private func cancel() {
        close()
        continuation?.resume(throwing: ScreenshotError.cancelled)
        continuation = nil
        Self.activeController = nil
    }
}

private final class SelectionOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionOverlayView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.22).setFill()
        bounds.fill()

        guard let selectionRect else { return }

        NSColor.clear.setFill()
        selectionRect.fill(using: .clear)

        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)

        guard let selectionRect else {
            onCancel?()
            return
        }

        onComplete?(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }

        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }
}
