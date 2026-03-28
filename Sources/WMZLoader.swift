import Foundation

enum WMZError: Error, LocalizedError {
    case unzipFailed(Int32)
    case noWMSFile

    var errorDescription: String? {
        switch self {
        case .unzipFailed(let code): return "unzip exited with status \(code)"
        case .noWMSFile: return "No .wms skin definition file found in archive"
        }
    }
}

struct WMZLoader {

    /// Unzips the .wmz archive into a fresh temp directory and returns its URL.
    static func extract(_ url: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wmz_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", url.path, "-d", tempDir.path]
        process.standardError = Pipe()   // suppress noise

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw WMZError.unzipFailed(process.terminationStatus)
        }

        ActionLogger.shared.log("Extracted \(url.lastPathComponent) → \(tempDir.path)")
        return tempDir
    }

    /// Recursively finds the first .wms file in `dir` (up to 2 levels deep).
    static func findWMS(in dir: URL) throws -> URL {
        let fm = FileManager.default

        func search(_ base: URL, depth: Int) -> URL? {
            guard let items = try? fm.contentsOfDirectory(
                at: base, includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ) else { return nil }

            if let wms = items.first(where: { $0.pathExtension.lowercased() == "wms" }) {
                return wms
            }
            guard depth > 0 else { return nil }
            for item in items {
                if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    if let found = search(item, depth: depth - 1) { return found }
                }
            }
            return nil
        }

        guard let wms = search(dir, depth: 2) else { throw WMZError.noWMSFile }
        return wms
    }
}
