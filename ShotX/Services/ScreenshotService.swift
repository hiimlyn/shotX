import AppKit
import ScreenCaptureKit

enum ScreenshotError: LocalizedError {
    case cancelled
    case noDisplayAvailable
    case noImageReturned
    case noLastCapture
    case imageEncodingFailed
    case selectionTooSmall

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The screenshot was cancelled."
        case .noDisplayAvailable:
            return "No display is available for capture."
        case .noImageReturned:
            return "ScreenCaptureKit did not return an image."
        case .noLastCapture:
            return "There is no previous capture to open."
        case .imageEncodingFailed:
            return "The screenshot could not be encoded as PNG."
        case .selectionTooSmall:
            return "The selected area is too small to capture."
        }
    }
}

@MainActor
final class ScreenshotService: NSObject {
    private var pickerContinuation: CheckedContinuation<SCContentFilter, Error>?

    override init() {
        super.init()

        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = .singleWindow
        configuration.allowsChangingSelectedContent = false

        let picker = SCContentSharingPicker.shared
        picker.defaultConfiguration = configuration
        picker.maximumStreamCount = 1
        picker.add(self)
        picker.isActive = false
    }

    deinit {
        let picker = SCContentSharingPicker.shared
        picker.isActive = false
        picker.remove(self)
    }

    func capturePickedWindow() async throws -> NSImage {
        let filter = try await pickWindowFilter()
        return try await capture(filter: filter)
    }

    func captureSelection() async throws -> NSImage {
        let appKitRect = try await SelectionOverlayController.pickRect()
        let captureRect = Self.displaySpaceRect(from: appKitRect)

        guard captureRect.width >= 2, captureRect.height >= 2 else {
            throw ScreenshotError.selectionTooSmall
        }

        let cgImage = try await SCScreenshotManager.captureImage(in: captureRect)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    func captureMainDisplay() async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw ScreenshotError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }
        return try await capture(filter: filter)
    }

    private func pickWindowFilter() async throws -> SCContentFilter {
        if pickerContinuation != nil {
            throw ScreenshotError.cancelled
        }

        return try await withCheckedThrowingContinuation { continuation in
            pickerContinuation = continuation
            let picker = SCContentSharingPicker.shared
            picker.isActive = true
            picker.present(using: .window)
        }
    }

    private func capture(filter: SCContentFilter) async throws -> NSImage {
        let configuration = SCStreamConfiguration()
        configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = true
        configuration.capturesAudio = false

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    private static func displaySpaceRect(from appKitRect: CGRect) -> CGRect {
        guard let mainDisplayFrame = appKitMainDisplayFrame() else {
            return appKitRect.standardized
        }

        // AppKit screen coordinates are bottom-left based. ScreenCaptureKit's
        // rectangle capture uses display space, which is top-left based.
        return CGRect(
            x: appKitRect.minX,
            y: mainDisplayFrame.maxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        ).standardized
    }

    private static func appKitMainDisplayFrame() -> CGRect? {
        let mainDisplayID = CGMainDisplayID()

        return NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }

            return screenNumber.uint32Value == mainDisplayID
        }?.frame ?? NSScreen.screens.first?.frame
    }

    private func finishPickingWindow(with result: Result<SCContentFilter, Error>) {
        let continuation = pickerContinuation
        pickerContinuation = nil
        SCContentSharingPicker.shared.isActive = false

        switch result {
        case .success(let filter):
            continuation?.resume(returning: filter)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

extension ScreenshotService: SCContentSharingPickerObserver {
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            finishPickingWindow(with: .failure(ScreenshotError.cancelled))
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            finishPickingWindow(with: .success(filter))
        }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in
            finishPickingWindow(with: .failure(error))
        }
    }
}
