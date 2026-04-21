import Foundation

struct SettingsService {
    private static let saveFolderKey = "saveFolderPath"

    var saveFolderURL: URL {
        if let path = UserDefaults.standard.string(forKey: Self.saveFolderKey), !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        return (picturesURL ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent("ShotX", isDirectory: true)
    }

    var saveFolderDisplayPath: String {
        saveFolderURL.path
    }

    func setSaveFolderURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: Self.saveFolderKey)
    }

    func nextCaptureURL() throws -> URL {
        let folderURL = saveFolderURL
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let baseName = "ShotX-\(Self.timestamp())"
        var candidate = folderURL.appendingPathComponent("\(baseName).png")
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(baseName)-\(index).png")
            index += 1
        }

        return candidate
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
