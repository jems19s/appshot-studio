import Foundation

enum Chrome {
    #if os(macOS)
    static let candidates = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    ]
    #else
    static let candidates = [
        "google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "microsoft-edge",
    ]
    #endif

    static func find(_ explicit: String?) throws -> String {
        if let explicit = explicit ?? ProcessInfo.processInfo.environment["CHROME"] {
            guard let found = resolve(explicit) else {
                throw AppshotError("Chrome not found at '\(explicit)'")
            }
            return found
        }
        for candidate in candidates {
            if let found = resolve(candidate) { return found }
        }
        throw AppshotError("no Chrome/Chromium found — install Google Chrome, or pass --chrome / set $CHROME")
    }

    private static func resolve(_ command: String) -> String? {
        if FileManager.default.isExecutableFile(atPath: command) { return command }
        guard !command.contains("/") else { return nil }
        let searchPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in searchPath.split(separator: ":") {
            let candidate = join(String(directory), command)
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    static func extraFlags() -> [String] {
        (ProcessInfo.processInfo.environment["CHROME_FLAGS"] ?? "")
            .split(separator: " ").map(String.init)
    }

    // No --user-data-dir here on purpose: a fresh profile makes Chrome treat
    // itself as newly installed and launch GoogleUpdater on every run — which
    // macOS App Management then blocks with a "prevented from modifying apps"
    // notification (and the wake can stall headless runs for minutes).
    static func screenshot(page: String, output: String, width: Int, height: Int,
                           binary: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--headless=new", "--disable-gpu", "--hide-scrollbars",
                             "--allow-file-access-from-files", "--force-device-scale-factor=1",
                             "--window-size=\(width),\(height)",
                             "--default-background-color=00000000",
                             "--virtual-time-budget=3000"]
            + extraFlags()
            + ["--screenshot=\(output)", "file://\(page)"]
        let stderrPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let tail = String(data: stderrData, encoding: .utf8)?
                .split(separator: "\n").suffix(3).joined(separator: "\n") ?? ""
            throw AppshotError("Chrome exited with status \(process.terminationStatus)\n\(tail)")
        }
    }
}
