import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private var settingsService: SettingsService
    private let saveFolderField = NSTextField(labelWithString: "")

    init(settingsService: SettingsService) {
        self.settingsService = settingsService

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShotX Settings"
        window.center()

        super.init(window: window)
        configureContent()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refresh()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else { return }

        let sidebar = NSStackView()
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 8
        sidebar.edgeInsets = NSEdgeInsets(top: 18, left: 16, bottom: 18, right: 12)
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let generalItem = NSTextField(labelWithString: "General")
        generalItem.font = .systemFont(ofSize: 13, weight: .semibold)
        sidebar.addArrangedSubview(generalItem)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "General")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let saveTitle = NSTextField(labelWithString: "Save Location")
        saveTitle.font = .systemFont(ofSize: 13, weight: .semibold)

        saveFolderField.lineBreakMode = .byTruncatingMiddle
        saveFolderField.maximumNumberOfLines = 1
        saveFolderField.textColor = .secondaryLabelColor
        saveFolderField.translatesAutoresizingMaskIntoConstraints = false

        let chooseButton = NSButton(title: "Choose Folder...", target: self, action: #selector(chooseFolder))
        chooseButton.bezelStyle = .rounded

        let folderRow = NSStackView(views: [saveFolderField, chooseButton])
        folderRow.orientation = .horizontal
        folderRow.alignment = .centerY
        folderRow.spacing = 12
        folderRow.translatesAutoresizingMaskIntoConstraints = false

        let saveSection = NSStackView(views: [saveTitle, folderRow])
        saveSection.orientation = .vertical
        saveSection.alignment = .leading
        saveSection.spacing = 8
        saveSection.translatesAutoresizingMaskIntoConstraints = false

        content.addArrangedSubview(title)
        content.addArrangedSubview(saveSection)

        contentView.addSubview(sidebar)
        contentView.addSubview(divider)
        contentView.addSubview(content)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 150),

            divider.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            divider.topAnchor.constraint(equalTo: contentView.topAnchor),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            content.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            folderRow.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -48),
            saveFolderField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    private func refresh() {
        saveFolderField.stringValue = settingsService.saveFolderDisplayPath
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settingsService.saveFolderURL

        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                self?.settingsService.setSaveFolderURL(url)
                self?.refresh()
            }
        }
    }
}
