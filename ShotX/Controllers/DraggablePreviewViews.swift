import AppKit

@MainActor
final class DraggableVisualEffectView: NSVisualEffectView {
    var onDragStarted: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onDragStarted?()
        window?.performDrag(with: event)
    }
}

@MainActor
final class DraggableView: NSView {
    var onDragStarted: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onDragStarted?()
        window?.performDrag(with: event)
    }
}

@MainActor
final class DraggableStackView: NSStackView {
    var onDragStarted: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onDragStarted?()
        window?.performDrag(with: event)
    }
}
