import AppKit

@MainActor
extension PreviewWindowController {
    func configureCompactPreview() {
        guard let contentView = window?.contentView else { return }

        let markCompactPreviewMoved: () -> Void = { [weak self] in
            self?.compactPreviewWasMoved = true
        }

        let container = makeCompactContainer(onDragStarted: markCompactPreviewMoved)
        let closeButton = Self.closeButton(
            symbolName: "xmark",
            accessibilityDescription: "Close",
            action: #selector(closeCompactPreview),
            target: self
        )

        let badge = makeBadge()
        let badgeIcon = makeBadgeIcon()
        configureTitleFields()

        let titleStack = DraggableStackView(views: [titleField, detailField])
        titleStack.onDragStarted = markCompactPreviewMoved
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let header = DraggableStackView(views: [badge, titleStack])
        header.onDragStarted = markCompactPreviewMoved
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        let thumbnailShell = makeThumbnailShell(onDragStarted: markCompactPreviewMoved)
        configureThumbnailImageView()

        let controls = makeCompactControls()
        let compactStack = DraggableStackView(views: [header, thumbnailShell, controls])
        compactStack.onDragStarted = markCompactPreviewMoved
        compactStack.orientation = .vertical
        compactStack.alignment = .centerX
        compactStack.spacing = 10
        compactStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(container)
        container.addSubview(compactStack)
        container.addSubview(closeButton)
        thumbnailShell.addSubview(thumbnailImageView)
        badge.addSubview(badgeIcon)

        activateCompactConstraints(
            contentView: contentView,
            container: container,
            closeButton: closeButton,
            compactStack: compactStack,
            header: header,
            badge: badge,
            badgeIcon: badgeIcon,
            thumbnailShell: thumbnailShell,
            controls: controls
        )
    }

    private func makeCompactContainer(onDragStarted: @escaping () -> Void) -> DraggableVisualEffectView {
        let container = DraggableVisualEffectView()
        container.onDragStarted = onDragStarted
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    private func makeBadge() -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 9
        badge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.9).cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        return badge
    }

    private func makeBadgeIcon() -> NSImageView {
        let badgeIcon = NSImageView()
        badgeIcon.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Captured")
        badgeIcon.contentTintColor = .white
        badgeIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        return badgeIcon
    }

    private func configureTitleFields() {
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingMiddle
        detailField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func makeThumbnailShell(onDragStarted: @escaping () -> Void) -> DraggableView {
        let thumbnailShell = DraggableView()
        thumbnailShell.onDragStarted = onDragStarted
        thumbnailShell.wantsLayer = true
        thumbnailShell.layer?.cornerRadius = 12
        thumbnailShell.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        thumbnailShell.layer?.borderWidth = 1
        thumbnailShell.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        thumbnailShell.translatesAutoresizingMaskIntoConstraints = false
        return thumbnailShell
    }

    private func configureThumbnailImageView() {
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 9
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func makeCompactControls() -> NSStackView {
        let previewButton = Self.compactIconButton(
            symbolName: "wand.and.stars",
            accessibilityDescription: "Preview",
            action: #selector(showEditor),
            target: self
        )
        previewButton.toolTip = "Preview"

        let saveButton = Self.compactIconButton(
            symbolName: "square.and.arrow.down",
            accessibilityDescription: "Save",
            action: #selector(saveOriginalImage),
            target: self
        )
        saveButton.toolTip = "Save"
        saveButton.keyEquivalent = "\r"

        let controls = NSStackView(views: [previewButton, saveButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.distribution = .fill
        controls.spacing = 10
        controls.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            previewButton.widthAnchor.constraint(equalToConstant: 68),
            previewButton.heightAnchor.constraint(equalToConstant: 36),
            saveButton.widthAnchor.constraint(equalToConstant: 68),
            saveButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        return controls
    }

    private func activateCompactConstraints(
        contentView: NSView,
        container: NSView,
        closeButton: NSView,
        compactStack: NSView,
        header: NSView,
        badge: NSView,
        badgeIcon: NSView,
        thumbnailShell: NSView,
        controls: NSView
    ) {
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.widthAnchor.constraint(equalToConstant: Self.compactPreviewSize.width),
            container.heightAnchor.constraint(equalToConstant: Self.compactPreviewSize.height),

            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            compactStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            compactStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            compactStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            compactStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            thumbnailShell.widthAnchor.constraint(equalTo: compactStack.widthAnchor),
            thumbnailShell.heightAnchor.constraint(equalToConstant: 120),

            thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailShell.leadingAnchor, constant: 5),
            thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailShell.trailingAnchor, constant: -5),
            thumbnailImageView.topAnchor.constraint(equalTo: thumbnailShell.topAnchor, constant: 5),
            thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailShell.bottomAnchor, constant: -5),

            badge.widthAnchor.constraint(equalToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
            badgeIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),

            header.widthAnchor.constraint(equalTo: compactStack.widthAnchor, constant: -28),
            controls.trailingAnchor.constraint(equalTo: compactStack.trailingAnchor),
            controls.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private static func compactIconButton(
        symbolName: String,
        accessibilityDescription: String,
        action: Selector,
        target: AnyObject
    ) -> NSButton {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
        let button = NSButton(title: "", image: image ?? NSImage(), target: target, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11, weight: .medium)
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    private static func closeButton(
        symbolName: String,
        accessibilityDescription: String,
        action: Selector,
        target: AnyObject
    ) -> NSButton {
        let button = compactIconButton(
            symbolName: symbolName,
            accessibilityDescription: accessibilityDescription,
            action: action,
            target: target
        )
        button.bezelStyle = .circular
        button.controlSize = .regular
        button.contentTintColor = .secondaryLabelColor
        return button
    }
}
