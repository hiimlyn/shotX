import AppKit

@MainActor
extension PreviewWindowController {
    func makeEditorWindow() -> NSWindow {
        let editorWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.editorMaximumSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        editorWindow.title = "ShotX Studio"
        editorWindow.isReleasedWhenClosed = false
        editorWindow.minSize = NSSize(width: 860, height: 560)
        editorWindow.maxSize = Self.editorMaximumSize

        let root = NSView()
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        canvasView.translatesAutoresizingMaskIntoConstraints = false

        let sidebar = makeInspector()
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(canvasView)
        root.addSubview(divider)
        root.addSubview(sidebar)
        editorWindow.contentView = root

        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            canvasView.topAnchor.constraint(equalTo: root.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            divider.leadingAnchor.constraint(equalTo: canvasView.trailingAnchor),
            divider.topAnchor.constraint(equalTo: root.topAnchor),
            divider.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            sidebar.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 300),

            canvasView.widthAnchor.constraint(greaterThanOrEqualToConstant: 560)
        ])

        self.editorWindow = editorWindow
        return editorWindow
    }

    private func makeInspector() -> NSView {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 26, left: 22, bottom: 22, right: 22)

        let presetField = NSTextField(string: "Your Preset")
        presetField.font = .systemFont(ofSize: 16, weight: .semibold)
        presetField.isEditable = false
        presetField.isBordered = true
        presetField.bezelStyle = .roundedBezel

        content.addArrangedSubview(presetField)
        content.addArrangedSubview(Self.separator())
        content.addArrangedSubview(makeAnnotationSection())
        content.addArrangedSubview(Self.separator())
        content.addArrangedSubview(makeSliderRow(title: "Padding", value: 0.28, tag: 1))
        content.addArrangedSubview(makeSliderRow(title: "Inset", value: 0.10, tag: 2))
        content.addArrangedSubview(makeDualSliderRow())
        content.addArrangedSubview(makeBackgroundSection())
        content.addArrangedSubview(makeRatioSection())

        let saveButton = NSButton(title: "Save Styled Screenshot", target: self, action: #selector(saveStyledImage))
        saveButton.bezelStyle = .rounded
        saveButton.controlSize = .large
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        content.addArrangedSubview(saveButton)

        NSLayoutConstraint.activate([
            presetField.widthAnchor.constraint(equalToConstant: 256),
            saveButton.widthAnchor.constraint(equalToConstant: 256)
        ])

        return content
    }

    private func makeSliderRow(title: String, value: Double, tag: Int) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14, weight: .medium)

        let slider = NSSlider(value: value, minValue: 0, maxValue: 1, target: self, action: #selector(sliderChanged(_:)))
        slider.tag = tag
        slider.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [label, slider])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            slider.widthAnchor.constraint(equalToConstant: 256)
        ])

        return stack
    }

    private func makeDualSliderRow() -> NSView {
        let radius = makeSliderRow(title: "Border Radius", value: 0.28, tag: 3)
        let shadow = makeSliderRow(title: "Shadow", value: 0.60, tag: 4)

        let stack = NSStackView(views: [radius, shadow])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        radius.widthAnchor.constraint(equalToConstant: 121).isActive = true
        shadow.widthAnchor.constraint(equalToConstant: 121).isActive = true

        return stack
    }

    private func makeAnnotationSection() -> NSView {
        let label = NSTextField(labelWithString: "Annotate")
        label.font = .systemFont(ofSize: 14, weight: .medium)

        let tools: [(String, Int)] = [
            ("Draw", 1),
            ("Highlight", 2),
            ("Censor", 3),
            ("Rect", 4),
            ("Oval", 5),
            ("Arrow", 6)
        ]
        annotationToolButtons.removeAll()
        for tool in tools {
            let button = pillButton(title: tool.0, tag: tool.1, action: #selector(annotationToolChanged(_:)))
            annotationToolButtons.append(button)
        }

        let toolGrid = NSStackView()
        toolGrid.orientation = .vertical
        toolGrid.alignment = .leading
        toolGrid.spacing = 6
        for rowIndex in 0..<2 {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 6

            for columnIndex in 0..<3 {
                row.addArrangedSubview(annotationToolButtons[rowIndex * 3 + columnIndex])
            }

            toolGrid.addArrangedSubview(row)
        }

        let colorRow = NSStackView()
        colorRow.orientation = .horizontal
        colorRow.spacing = 6

        let colors: [(NSColor, Int)] = [
            (.systemRed, 1),
            (.systemYellow, 2),
            (.systemBlue, 3),
            (.systemGreen, 4),
            (.black, 5),
            (.white, 6)
        ]
        for (color, tag) in colors {
            let button = NSButton()
            button.tag = tag
            button.bezelStyle = .shadowlessSquare
            button.controlSize = .small
            button.wantsLayer = true
            button.layer?.cornerRadius = 4
            button.layer?.backgroundColor = color.cgColor
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.separatorColor.cgColor
            button.target = self
            button.action = #selector(annotationColorChanged(_:))
            button.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 32),
                button.heightAnchor.constraint(equalToConstant: 32)
            ])

            colorRow.addArrangedSubview(button)
        }

        let widthLabel = NSTextField(labelWithString: "Width")
        widthLabel.font = .systemFont(ofSize: 12)
        let widthSlider = NSSlider(value: 5, minValue: 1, maxValue: 24, target: self, action: #selector(annotationWidthChanged(_:)))
        widthSlider.translatesAutoresizingMaskIntoConstraints = false
        let widthRow = NSStackView(views: [widthLabel, widthSlider])
        widthRow.orientation = .horizontal
        widthRow.spacing = 8

        NSLayoutConstraint.activate([
            widthSlider.widthAnchor.constraint(equalToConstant: 190)
        ])

        let utilityRow = NSStackView()
        utilityRow.orientation = .horizontal
        utilityRow.spacing = 8

        let undoButton = NSButton(title: "Undo", target: self, action: #selector(undoAnnotation))
        undoButton.bezelStyle = .rounded
        undoButton.controlSize = .small
        let redoButton = NSButton(title: "Redo", target: self, action: #selector(redoAnnotation))
        redoButton.bezelStyle = .rounded
        redoButton.controlSize = .small
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearAnnotations))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        utilityRow.addArrangedSubview(undoButton)
        utilityRow.addArrangedSubview(redoButton)
        utilityRow.addArrangedSubview(clearButton)

        let stack = NSStackView(views: [label, toolGrid, colorRow, widthRow, utilityRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func makeBackgroundSection() -> NSView {
        let label = NSTextField(labelWithString: "Background")
        label.font = .systemFont(ofSize: 14, weight: .medium)

        let styles: [(ScreenshotCanvasView.BackgroundStyle, String)] = [
            (.desktop, "Desktop"),
            (.aurora, "Aurora"),
            (.nice, "Nice"),
            (.morning, "Morning"),
            (.bright, "Bright"),
            (.love, "Love"),
            (.rain, "Rain"),
            (.sky, "Sky"),
            (.none, "None"),
            (.custom, "Custom")
        ]

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 8

        for rowIndex in 0..<2 {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8

            for columnIndex in 0..<5 {
                let index = rowIndex * 5 + columnIndex
                let button = backgroundButton(style: styles[index].0, title: styles[index].1)
                row.addArrangedSubview(button)
            }

            grid.addArrangedSubview(row)
        }

        let stack = NSStackView(views: [label, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func makeRatioSection() -> NSView {
        let label = NSTextField(labelWithString: "Ratio / Size")
        label.font = .systemFont(ofSize: 14, weight: .medium)

        let ratioRow = NSStackView()
        ratioRow.orientation = .horizontal
        ratioRow.spacing = 6

        let ratios: [(String, Int)] = [("Auto", 1), ("4:3", 2), ("3:2", 3), ("16:9", 4), ("1:1", 5)]
        for ratio in ratios {
            let button = pillButton(title: ratio.0, tag: ratio.1, action: #selector(ratioChanged(_:)))
            ratioRow.addArrangedSubview(button)
        }

        let stack = NSStackView(views: [label, ratioRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    private func backgroundButton(style: ScreenshotCanvasView.BackgroundStyle, title: String) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(backgroundChanged(_:)))
        button.tag = style.rawValue
        button.bezelStyle = .shadowlessSquare
        button.controlSize = .small
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = style.previewColor.cgColor
        button.layer?.borderWidth = style == .none ? 1 : 0
        button.layer?.borderColor = NSColor.separatorColor.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 45),
            button.heightAnchor.constraint(equalToConstant: 45)
        ])

        return button
    }

    private func pillButton(title: String, tag: Int, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.tag = tag
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.imagePosition = .imageLeading
        button.setButtonType(.toggle)
        return button
    }

    private static func separator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}
