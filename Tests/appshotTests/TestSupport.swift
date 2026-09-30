import Foundation
@testable import appshot

final class TemporaryDirectory {
    let path: String

    init() throws {
        path = join(FileManager.default.temporaryDirectory.path, "appshot-tests-\(UUID().uuidString)")
        try FileManager.default.ensureDirectory(path)
    }

    deinit {
        try? FileManager.default.removeItem(atPath: path)
    }
}

func thrownMessage(_ body: () throws -> Any) -> String {
    do {
        _ = try body()
        return "nothing thrown"
    } catch {
        return String(describing: error)
    }
}
