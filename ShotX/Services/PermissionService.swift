import AppKit
import CoreGraphics

struct PermissionService {
    private static let guidanceShownKey = "screenRecordingGuidanceShown"

    func prepareForScreenCapture() {
        if CGPreflightScreenCaptureAccess() {
            return
        }

        guard !UserDefaults.standard.bool(forKey: Self.guidanceShownKey) else {
            return
        }

        let granted = CGRequestScreenCaptureAccess()
        UserDefaults.standard.set(true, forKey: Self.guidanceShownKey)

        if !granted {
            showScreenRecordingGuidance()
        }
    }

    func showScreenRecordingGuidance(requestAccess: Bool = false) {
        let hasPermission = CGPreflightScreenCaptureAccess()

        if hasPermission && !requestAccess {
            let alert = NSAlert()
            alert.messageText = "Screen Recording is enabled"
            alert.informativeText = "ShotX already has Screen Recording permission."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        if requestAccess {
            _ = CGRequestScreenCaptureAccess()
        }

        let alert = NSAlert()
        alert.messageText = "Screen Recording permission is required"
        alert.informativeText = "Enable Screen Recording for ShotX in System Settings, then restart the app if capture still fails."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    private func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
