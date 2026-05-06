import AppKit

@MainActor
final class ScreenshotCanvasView: NSView {

    // MARK: - Annotation Tools

    enum AnnotationTool: Int {
        case none = 0
        case pen = 1
        case highlight = 2
        case censor = 3
        case rectangle = 4
        case oval = 5
        case arrow = 6
    }

    struct AnnotationStyle {
        var color: NSColor
        var lineWidth: CGFloat
        var fillAlpha: CGFloat = 1.0

        static let defaultPen = AnnotationStyle(color: .systemRed, lineWidth: 5)
        static let defaultHighlight = AnnotationStyle(color: .systemYellow, lineWidth: 14, fillAlpha: 0.35)
        static let defaultCensor = AnnotationStyle(color: .black, lineWidth: 0)
        static let defaultShape = AnnotationStyle(color: .systemRed, lineWidth: 4)
    }

    struct Annotation {
        var tool: AnnotationTool
        var points: [CGPoint]
        var rect: CGRect?
        var style: AnnotationStyle
    }

    private struct CanvasLayout {
        let stageRect: NSRect
        let cardRect: NSRect
        let imageRect: NSRect
        let cardRadius: CGFloat
    }

    // MARK: - Canvas State

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

    // MARK: - Image Properties

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

    // MARK: - Annotation Properties

    var selectedAnnotationTool: AnnotationTool = .none {
        didSet { needsDisplay = true }
    }

    var annotationColor: NSColor = .systemRed {
        didSet { needsDisplay = true }
    }

    var annotationLineWidth: CGFloat = 5 {
        didSet { needsDisplay = true }
    }

    private(set) var annotations: [Annotation] = []
    private var undoneAnnotations: [Annotation] = []
    private var activeAnnotation: Annotation?
    private var dragStartPoint: CGPoint?

    // MARK: - Zoom

    private static let minimumZoom: CGFloat = 0.5
    private static let maximumZoom: CGFloat = 4.0

    var zoomScale: CGFloat = 1.0 {
        didSet {
            zoomScale = min(max(zoomScale, Self.minimumZoom), Self.maximumZoom)
            needsDisplay = true
        }
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1).cgColor
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            super.keyDown(with: event)
            return
        }

        switch key {
        case "z":
            undoLastAnnotation()
        case "y":
            redoLastAnnotation()
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Public Annotation API

    func undoLastAnnotation() {
        guard let annotation = annotations.popLast() else { return }
        undoneAnnotations.append(annotation)
        needsDisplay = true
    }

    func redoLastAnnotation() {
        guard let annotation = undoneAnnotations.popLast() else { return }
        annotations.append(annotation)
        needsDisplay = true
    }

    func clearAnnotations() {
        annotations.removeAll()
        undoneAnnotations.removeAll()
        needsDisplay = true
    }

    // MARK: - Mouse Events

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.control) else {
            super.scrollWheel(with: event)
            return
        }

        zoomScale += -event.scrollingDeltaY * 0.01
    }

    override func mouseDown(with event: NSEvent) {
        guard selectedAnnotationTool != .none else { return }

        let point = convert(event.locationInWindow, from: nil)
        let layout = computeLayout(in: bounds)

        guard layout.imageRect.contains(point) else { return }

        guard let normalizedStart = normalizedPoint(point, in: layout.imageRect) else { return }
        dragStartPoint = normalizedStart

        var style = defaultStyle(for: selectedAnnotationTool)
        style.color = annotationColor

        switch selectedAnnotationTool {
        case .pen, .highlight:
            activeAnnotation = Annotation(tool: selectedAnnotationTool, points: [normalizedStart], rect: nil, style: style)
        case .rectangle, .oval, .censor:
            activeAnnotation = Annotation(tool: selectedAnnotationTool, points: [], rect: CGRect(origin: normalizedStart, size: .zero), style: style)
        case .arrow:
            activeAnnotation = Annotation(tool: selectedAnnotationTool, points: [normalizedStart, normalizedStart], rect: nil, style: style)
        case .none:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard var current = activeAnnotation else { return }

        let point = convert(event.locationInWindow, from: nil)
        let layout = computeLayout(in: bounds)
        guard let normalized = normalizedPoint(point, in: layout.imageRect) else { return }

        switch current.tool {
        case .pen, .highlight:
            current.points.append(normalized)
        case .rectangle, .oval, .censor:
            guard let start = dragStartPoint else { return }
            current.rect = CGRect(
                x: min(start.x, normalized.x),
                y: min(start.y, normalized.y),
                width: abs(normalized.x - start.x),
                height: abs(normalized.y - start.y)
            )
        case .arrow:
            current.points[1] = normalized
        case .none:
            break
        }

        activeAnnotation = current
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var current = activeAnnotation else { return }

        let point = convert(event.locationInWindow, from: nil)
        let layout = computeLayout(in: bounds)

        if let normalized = normalizedPoint(point, in: layout.imageRect) {
            switch current.tool {
            case .pen, .highlight:
                current.points.append(normalized)
            case .arrow:
                current.points[1] = normalized
            case .rectangle, .oval, .censor:
                break
            case .none:
                break
            }
        }

        if isAnnotationSignificant(current) {
            annotations.append(current)
            undoneAnnotations.removeAll()
        }

        activeAnnotation = nil
        dragStartPoint = nil
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
        bounds.fill()

        let layout = computeLayout(in: bounds)
        drawBackground(in: layout.stageRect)

        guard image != nil else { return }

        drawCard(in: layout.cardRect, radius: layout.cardRadius)
        image?.draw(in: layout.imageRect, from: .zero, operation: .sourceOver, fraction: 1)

        drawAnnotations(layout: layout)
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

    // MARK: - Private Helpers

    private func computeLayout(in bounds: NSRect) -> CanvasLayout {
        let canvasSpacing = Self.contentSpacing(for: bounds, value: padding)
        let baseStageRect = centeredStageRect(in: bounds.insetBy(dx: canvasSpacing, dy: canvasSpacing))
        let stageRect = NSRect(
            x: baseStageRect.midX - baseStageRect.width * zoomScale / 2,
            y: baseStageRect.midY - baseStageRect.height * zoomScale / 2,
            width: baseStageRect.width * zoomScale,
            height: baseStageRect.height * zoomScale
        )

        let cardSpacing = Self.contentSpacing(for: stageRect, value: padding)
        let imageSpacing = Self.contentSpacing(for: stageRect, value: inset)
        let cardRect = stageRect.insetBy(dx: cardSpacing, dy: cardSpacing)
        let radius = Self.cardRadius(for: cardRect, value: borderRadius)
        let imageSafeRect = cardRect.insetBy(dx: imageSpacing, dy: imageSpacing)
        let imageRect = (image?.size ?? NSSize(width: 1, height: 1)).aspectFit(in: imageSafeRect)

        return CanvasLayout(stageRect: stageRect, cardRect: cardRect, imageRect: imageRect, cardRadius: radius)
    }

    private func drawCard(in rect: NSRect, radius: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.08 + shadowStrength * 0.22)
        shadow.shadowBlurRadius = 10 + shadowStrength * 28
        shadow.shadowOffset = NSSize(width: 0, height: -6 - shadowStrength * 12)
        shadow.set()

        NSColor.white.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func normalizedPoint(_ point: CGPoint, in imageRect: NSRect) -> CGPoint? {
        guard imageRect.width > 0, imageRect.height > 0 else { return nil }
        let x = (point.x - imageRect.minX) / imageRect.width
        let y = (point.y - imageRect.minY) / imageRect.height
        return CGPoint(x: x, y: y)
    }

    private func denormalizedPoint(_ point: CGPoint, in imageRect: NSRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + point.x * imageRect.width,
            y: imageRect.minY + point.y * imageRect.height
        )
    }

    private func denormalizedRect(_ rect: CGRect, in imageRect: NSRect) -> NSRect {
        NSRect(
            x: imageRect.minX + rect.minX * imageRect.width,
            y: imageRect.minY + rect.minY * imageRect.height,
            width: rect.width * imageRect.width,
            height: rect.height * imageRect.height
        )
    }

    private func defaultStyle(for tool: AnnotationTool) -> AnnotationStyle {
        switch tool {
        case .pen: return .defaultPen
        case .highlight: return .defaultHighlight
        case .censor: return .defaultCensor
        case .rectangle, .oval, .arrow: return .defaultShape
        case .none: return .defaultPen
        }
    }

    private func isAnnotationSignificant(_ annotation: Annotation) -> Bool {
        switch annotation.tool {
        case .pen, .highlight:
            return annotation.points.count >= 2
        case .rectangle, .oval, .censor:
            guard let rect = annotation.rect else { return false }
            return rect.width > 0.005 && rect.height > 0.005
        case .arrow:
            guard annotation.points.count >= 2 else { return false }
            let dx = annotation.points[1].x - annotation.points[0].x
            let dy = annotation.points[1].y - annotation.points[0].y
            return sqrt(dx * dx + dy * dy) > 0.01
        case .none:
            return false
        }
    }

    // MARK: - Annotation Drawing

    private func drawAnnotations(layout: CanvasLayout) {
        for annotation in annotations {
            drawAnnotation(annotation, layout: layout)
        }

        if let activeAnnotation {
            drawActiveAnnotation(activeAnnotation, layout: layout)
        }
    }

    private func drawActiveAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        if annotation.tool == .censor, let rect = annotation.rect {
            let denormRect = denormalizedRect(rect, in: layout.imageRect)
            drawCensorSelectionOutline(in: denormRect)
        } else {
            drawAnnotation(annotation, layout: layout)
        }
    }

    private func drawAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        switch annotation.tool {
        case .pen:
            drawPenAnnotation(annotation, layout: layout)
        case .highlight:
            drawHighlightAnnotation(annotation, layout: layout)
        case .rectangle:
            drawRectangleAnnotation(annotation, layout: layout)
        case .oval:
            drawOvalAnnotation(annotation, layout: layout)
        case .arrow:
            drawArrowAnnotation(annotation, layout: layout)
        case .censor:
            drawCensorAnnotation(annotation, layout: layout)
        case .none:
            break
        }
    }

    private func drawPenAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        guard annotation.points.count >= 2 else { return }

        let path = NSBezierPath()
        path.lineWidth = annotation.style.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let start = denormalizedPoint(annotation.points[0], in: layout.imageRect)
        path.move(to: start)

        for i in 1..<annotation.points.count {
            let point = denormalizedPoint(annotation.points[i], in: layout.imageRect)
            path.line(to: point)
        }

        annotation.style.color.setStroke()
        path.stroke()
    }

    private func drawHighlightAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        guard annotation.points.count >= 2 else { return }

        let path = NSBezierPath()
        path.lineWidth = annotation.style.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let start = denormalizedPoint(annotation.points[0], in: layout.imageRect)
        path.move(to: start)

        for i in 1..<annotation.points.count {
            let point = denormalizedPoint(annotation.points[i], in: layout.imageRect)
            path.line(to: point)
        }

        annotation.style.color.withAlphaComponent(annotation.style.fillAlpha).setStroke()
        path.stroke()
    }

    private func drawRectangleAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        guard let rect = annotation.rect else { return }
        let denormRect = denormalizedRect(rect, in: layout.imageRect)

        let path = NSBezierPath(rect: denormRect)
        path.lineWidth = annotation.style.lineWidth
        annotation.style.color.setStroke()
        path.stroke()
    }

    private func drawOvalAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        guard let rect = annotation.rect else { return }
        let denormRect = denormalizedRect(rect, in: layout.imageRect)

        let path = NSBezierPath(ovalIn: denormRect)
        path.lineWidth = annotation.style.lineWidth
        annotation.style.color.setStroke()
        path.stroke()
    }

    private func drawArrowAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        guard annotation.points.count >= 2 else { return }

        let start = denormalizedPoint(annotation.points[0], in: layout.imageRect)
        let end = denormalizedPoint(annotation.points[1], in: layout.imageRect)

        let lineWidth = annotation.style.lineWidth

        let linePath = NSBezierPath()
        linePath.move(to: start)
        linePath.line(to: end)
        linePath.lineWidth = lineWidth
        annotation.style.color.setStroke()
        linePath.stroke()

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let unitX = dx / length
        let unitY = dy / length
        let perpX = -unitY
        let perpY = unitX

        let arrowLength = max(8, lineWidth * 2.5)
        let arrowWidth = max(4, lineWidth * 1.2)

        let arrowTip = end
        let arrowLeft = CGPoint(
            x: end.x - unitX * arrowLength + perpX * arrowWidth,
            y: end.y - unitY * arrowLength + perpY * arrowWidth
        )
        let arrowRight = CGPoint(
            x: end.x - unitX * arrowLength - perpX * arrowWidth,
            y: end.y - unitY * arrowLength - perpY * arrowWidth
        )

        let arrowPath = NSBezierPath()
        arrowPath.move(to: arrowTip)
        arrowPath.line(to: arrowLeft)
        arrowPath.line(to: arrowRight)
        arrowPath.close()
        annotation.style.color.setFill()
        arrowPath.fill()
    }

    private func drawCensorAnnotation(_ annotation: Annotation, layout: CanvasLayout) {
        guard let rect = annotation.rect, let screenshotImage = image else { return }
        let denormRect = denormalizedRect(rect, in: layout.imageRect)

        var proposedRect = NSRect(origin: .zero, size: screenshotImage.size)
        guard let cgImage = screenshotImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            NSColor.black.setFill()
            denormRect.fill()
            return
        }

        let sourceRect = CGRect(
            x: rect.minX * CGFloat(cgImage.width),
            y: (1 - rect.maxY) * CGFloat(cgImage.height),
            width: rect.width * CGFloat(cgImage.width),
            height: rect.height * CGFloat(cgImage.height)
        ).integral

        guard sourceRect.width > 0,
              sourceRect.height > 0,
              let croppedImage = cgImage.cropping(to: sourceRect) else {
            NSColor.black.setFill()
            denormRect.fill()
            return
        }

        let pixelSize: CGFloat = 12
        let pixelImage = NSImage(size: NSSize(
            width: max(1, sourceRect.width / pixelSize),
            height: max(1, sourceRect.height / pixelSize)
        ))

        pixelImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .low
        NSImage(cgImage: croppedImage, size: NSSize(width: sourceRect.width, height: sourceRect.height)).draw(
            in: NSRect(origin: .zero, size: pixelImage.size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        pixelImage.unlockFocus()

        NSGraphicsContext.current?.imageInterpolation = .none
        pixelImage.draw(in: denormRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private func drawCensorSelectionOutline(in rect: NSRect) {
        let outline = NSBezierPath(rect: rect)
        outline.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        outline.stroke()

        let fillPath = NSBezierPath(rect: rect)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        fillPath.fill()
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
