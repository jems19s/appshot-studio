import Foundation

struct AppshotError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}

enum Studio {
    static func root(_ override: String?) -> String {
        let path = override ?? FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func appNames(root: String) -> [String] {
        let appsDir = join(root, "apps")
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: appsDir)) ?? []
        return entries.filter { FileManager.default.fileExists(atPath: join(appsDir, $0, "config.json")) }
            .sorted()
    }

    static func onlyApp(root: String) throws -> String {
        let appsInStudio = appNames(root: root)
        guard appsInStudio.count == 1 else {
            let appsDir = join(root, "apps")
            throw AppshotError(appsInStudio.isEmpty
                ? "no app in \(appsDir) yet — create one with `appshot init`"
                : "several apps in \(appsDir): \(appsInStudio.joined(separator: ", ")) — pick one with --app <name>")
        }
        return appsInStudio[0]
    }
}

func join(_ parts: String...) -> String {
    parts.dropFirst().reduce(parts[0]) { ($0 as NSString).appendingPathComponent($1) }
}

extension FileManager {
    func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func ensureDirectory(_ path: String) throws {
        try createDirectory(atPath: path, withIntermediateDirectories: true)
    }
}

func loadJSON<T: Decodable>(_ type: T.Type, at path: String, what: String) throws -> T {
    guard let data = FileManager.default.contents(atPath: path) else {
        throw AppshotError("missing \(what) at \(path)")
    }
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw AppshotError("cannot parse \(what) at \(path): \(error)")
    }
}

func writeJSON<T: Encodable>(_ value: T, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var data = try encoder.encode(value)
    data.append(UInt8(ascii: "\n"))
    try data.write(to: URL(fileURLWithPath: path))
}

func httpGet(_ urlString: String) throws -> Data {
    guard let url = URL(string: urlString) else { throw AppshotError("bad URL \(urlString)") }
    var request = URLRequest(url: url)
    request.setValue("appshot-studio", forHTTPHeaderField: "User-Agent")
    let semaphore = DispatchSemaphore(value: 0)
    var received: Data?
    var failure: Error?
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error {
            failure = error
        } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            failure = AppshotError("HTTP \(http.statusCode) from \(url)")
        } else {
            received = data
        }
        semaphore.signal()
    }.resume()
    semaphore.wait()
    if let failure { throw AppshotError("network request failed: \(failure)") }
    return received ?? Data()
}
