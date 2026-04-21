import AppKit

@MainActor
final class ScreenshotCanvasView: NSView {
    private static let preferredContentSpacing: CGFloat = 32
    private static let minimumContentSpacing: CGFloat = 12
    private static let maximumContentSpacing: CGFloat = 96

    enum BackgroundStyle: Int {
        case desktop = 1
        case aurora = 2
        case nice = 3
        case morning = 4
        case bright = 5
        case love = 6
        case rain = 7
        case sky = 8
        case none = 9
        case custom = 10

        var previewColor: NSColor {
            switch self {
            case .desktop:
                return NSColor(calibratedRed: 0.97, green: 0.55, blue: 0.13, alpha: 1)
            case .aurora:
                return NSColor(calibratedRed: 0.10, green: 0.66, blue: 0.76, alpha: 1)
            case .nice:
                return NSColor(calibratedRed: 0.83, green: 0.19, blue: 0.48, alpha: 1)
            case .morning:
                return NSColor(calibratedRed: 0.95, green: 0.54, blue: 0.38, alpha: 1)
            case .bright:
                return NSColor(calibratedRed: 0.48, green: 0.39, blue: 0.88, alpha: 1)
            case .love:
                return NSColor(calibratedRed: 0.50, green: 0.07, blue: 0.78, alpha: 1)
            case .rain:
                return NSColor(calibratedRed: 0.83, green: 0.22, blue: 0.78, alpha: 1)
            case .sky:
                return NSColor(calibratedRed: 0.49, green: 0.85, blue: 0.93, alpha: 1)
            case .none:
                return .clear
            case .custom:
                return NSColor(calibratedRed: 0.80, green: 0.92, blue: 0.34, alpha: 1)
            }
        }
    }

    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    var padding: CGFloat = 0.28 {
        didSet { needsDisplay = true }
    }

    var inset: CGFloat = 0.10 {
        didSet { needsDisplay = true }
    }

    var borderRadius: CGFloat = 0.28 {
        didSet { needsDisplay = true }
    }

    var shadowStrength: CGFloat = 0.60 {
        didSet { needsDisplay = true }
    }

    var backgroundStyle: BackgroundStyle = .aurora {
        didSet { needsDisplay = true }
    }

    var aspectRatio: CGFloat? {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
        bounds.fill()

        let canvasSpacing = Self.contentSpacing(for: bounds, value: padding)
        let stageRect = centeredStageRect(in: bounds.insetBy(dx: canvasSpacing, dy: canvasSpacing))
        drawBackground(in: stageRect)

        guard let image else { return }

        let cardSpacing = Self.contentSpacing(for: stageRect, value: padding)
        let imageSpacing = Self.contentSpacing(for: stageRect, value: inset)
        let cardRect = stageRect.insetBy(dx: cardSpacing, dy: cardSpacing)
        let radius = Self.cardRadius(for: cardRect, value: borderRadius)
        let imageSafeRect = cardRect.insetBy(dx: imageSpacing, dy: imageSpacing)
        let imageRect = image.size.aspectFit(in: imageSafeRect)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.08 + shadowStrength * 0.22)
        shadow.shadowBlurRadius = 10 + shadowStrength * 28
        shadow.shadowOffset = NSSize(width: 0, height: -6 - shadowStrength * 12)
        shadow.set()

        NSColor.white.setFill()
        NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()

        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    func renderedImage() -> NSImage {
        let exportSize = NSSize(width: 1600, height: 1000)
        let image = NSImage(size: exportSize)
        image.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        let oldFrame = frame
        frame = NSRect(origin: .zero, size: exportSize)
        draw(bounds)
        frame = oldFrame

        image.unlockFocus()
        return image
    }

    private func centeredStageRect(in rect: NSRect) -> NSRect {
        let ratio = aspectRatio ?? 16.0 / 9.0
        var size = rect.size

        if size.width / size.height > ratio {
            size.width = size.height * ratio
        } else {
            size.height = size.width / ratio
        }

        return NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func contentSpacing(for rect: NSRect, value: CGFloat) -> CGFloat {
        let normalizedValue = min(max(value, 0), 1)
        let desiredSpacing = preferredContentSpacing + (normalizedValue - 0.28) * 80
        let responsiveMaximum = min(maximumContentSpacing, min(rect.width, rect.height) / 5)
        let maximumSpacing = max(minimumContentSpacing, responsiveMaximum)
        return min(max(desiredSpacing, minimumContentSpacing), maximumSpacing)
    }

    private static func cardRadius(for rect: NSRect, value: CGFloat) -> CGFloat {
        let maximumRadius = min(72, min(rect.width, rect.height) / 2)
        return max(4, maximumRadius * value)
    }

    private func drawBackground(in rect: NSRect) {
        switch backgroundStyle {
        case .desktop:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.19, alpha: 1),
                NSColor(calibratedRed: 0.91, green: 0.19, blue: 0.34, alpha: 1)
            ])?.draw(in: rect, angle: 315)
        case .aurora:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.37, green: 0.85, blue: 0.95, alpha: 1),
                NSColor(calibratedRed: 0.58, green: 0.45, blue: 0.94, alpha: 1),
                NSColor(calibratedRed: 1.00, green: 0.18, blue: 0.41, alpha: 1)
            ])?.draw(in: rect, angle: 315)
        case .nice:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.91, green: 0.27, blue: 0.60, alpha: 1),
                NSColor(calibratedRed: 0.73, green: 0.22, blue: 0.78, alpha: 1)
            ])?.draw(in: rect, angle: 0)
        case .morning:
            NSGradient(colors: [
                NSColor(calibratedRed: 1.00, green: 0.75, blue: 0.48, alpha: 1),
                NSColor(calibratedRed: 0.98, green: 0.48, blue: 0.39, alpha: 1)
            ])?.draw(in: rect, angle: 45)
        case .bright:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.58, green: 0.38, blue: 0.91, alpha: 1),
                NSColor(calibratedRed: 0.36, green: 0.70, blue: 0.95, alpha: 1)
            ])?.draw(in: rect, angle: 45)
        case .love:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.29, green: 0.02, blue: 0.65, alpha: 1),
                NSColor(calibratedRed: 0.96, green: 0.12, blue: 0.68, alpha: 1)
            ])?.draw(in: rect, angle: 315)
        case .rain:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.98, green: 0.48, blue: 0.70, alpha: 1),
                NSColor(calibratedRed: 0.33, green: 0.83, blue: 0.95, alpha: 1)
            ])?.draw(in: rect, angle: 315)
        case .sky:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.70, green: 0.91, blue: 0.98, alpha: 1),
                NSColor(calibratedRed: 0.50, green: 0.72, blue: 0.94, alpha: 1)
            ])?.draw(in: rect, angle: 0)
        case .none:
            NSColor.white.setFill()
            rect.fill()
        case .custom:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.80, green: 0.92, blue: 0.34, alpha: 1),
                NSColor(calibratedRed: 0.95, green: 0.41, blue: 0.62, alpha: 1),
                NSColor(calibratedRed: 0.80, green: 0.41, blue: 0.94, alpha: 1)
            ])?.draw(in: rect, angle: 315)
        }
    }
}

private extension NSSize {
    func aspectFit(in rect: NSRect) -> NSRect {
        guard width > 0, height > 0 else { return rect }

        let scale = min(rect.width / width, rect.height / height)
        let size = NSSize(width: width * scale, height: height * scale)
        return NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
