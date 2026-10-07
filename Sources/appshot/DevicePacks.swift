import Foundation
import PNG

enum FrameSource {
    static let rawBase = "https://raw.githubusercontent.com/fastlane/frameit-frames/gh-pages/latest/"

    static func upstreamNames() throws -> [String] {
        let frameFiles = try JSONDecoder().decode([String].self, from: httpGet(rawBase + "files.json"))
        return frameFiles.compactMap { file in
            file.hasSuffix(".png") ? String(file.dropLast(4)) : nil
        }.sorted()
    }

    /// frameit names look like "Apple iPhone 17 Pro Max Silver": a model, then a color.
    /// The query must match whole words. The words after it are the color, unless their
    /// first word continues a name that two or more frames share — then the frame belongs
    /// to a longer model ("Apple iPhone 17 Pro Silver" is not an "iPhone 17").
    static func framesByColor(for query: String, in names: [String]) throws -> [String: String] {
        let catalog = FrameCatalog(names: names)
        let queryName = FrameCatalog.FrameName(query)
        guard !queryName.words.isEmpty else { throw AppshotError("no device name given") }

        let matches = catalog.matches(of: queryName.comparableWords)
        let colorMatches = matches.filter(\.isColorOfQueriedModel)
        if Set(colorMatches.map(\.model)).count == 1 {
            return Dictionary(colorMatches.map { ($0.colorSlug, $0.frame.name) }) { _, last in last }
        }
        guard matches.isEmpty else {
            throw AppshotError("\"\(query)\" matches more than one device — pick one:"
                + listing(matches.map(\.model)))
        }
        for shorterQueryLength in stride(from: queryName.words.count - 1, to: 0, by: -1) {
            let nearbyModels = catalog.matches(of: Array(queryName.comparableWords.prefix(shorterQueryLength)))
                .map(\.model)
            guard nearbyModels.isEmpty else {
                let shorterQuery = queryName.words.prefix(shorterQueryLength).joined(separator: " ")
                throw AppshotError("no frame matches \"\(query)\" — devices matching \"\(shorterQuery)\":"
                    + listing(nearbyModels))
            }
        }
        throw AppshotError("no frame matches \"\(query)\" — try `appshot devices list`")
    }

    private static func listing(_ models: [String]) -> String {
        "\n  " + Set(models).sorted().joined(separator: "\n  ")
    }

    static func download(name: String) throws -> Data {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try httpGet(rawBase + encoded + ".png")
    }

    static func slug(_ text: String) -> String {
        var out = ""
        var previousWasDash = true
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                out.append(character)
                previousWasDash = false
            } else if !previousWasDash {
                out.append("-")
                previousWasDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }
}

private struct FrameCatalog {
    struct FrameName {
        let name: String
        let words: [Substring]
        let comparableWords: [String]

        init(_ name: String) {
            self.name = name
            words = name.split { $0 == " " || $0 == "-" }
            comparableWords = words.map { $0.lowercased() }
        }
    }

    struct Match {
        let frame: FrameName
        let queryEnd: Int
        let modelWordCount: Int

        var model: String { String(frame.name[..<frame.words[modelWordCount - 1].endIndex]) }
        var isColorOfQueriedModel: Bool { modelWordCount == queryEnd }
        var colorSlug: String {
            let colorText = frame.words[queryEnd...].joined(separator: " ")
            return FrameSource.slug(colorText.isEmpty ? "standard" : colorText)
        }
    }

    private let frames: [FrameName]
    private let frameCountByPrefix: [[String]: Int]

    init(names: [String]) {
        frames = names.map(FrameName.init)
        var frameCountByPrefix: [[String]: Int] = [:]
        for frame in frames {
            for lastWord in frame.comparableWords.indices {
                frameCountByPrefix[Array(frame.comparableWords[...lastWord]), default: 0] += 1
            }
        }
        self.frameCountByPrefix = frameCountByPrefix
    }

    func matches(of queryWords: [String]) -> [Match] {
        frames.compactMap { frame in
            guard let queryRange = frame.comparableWords.firstRange(of: queryWords) else { return nil }
            var modelWordCount = queryRange.upperBound
            while modelWordCount < frame.words.count,
                  frameCountByPrefix[Array(frame.comparableWords[...modelWordCount]), default: 0] >= 2 {
                modelWordCount += 1
            }
            return Match(frame: frame, queryEnd: queryRange.upperBound, modelWordCount: modelWordCount)
        }
    }
}

enum DevicePackBuilder {
    static let alphaThreshold: UInt8 = 16

    static func fetch(query: String, colorFilter: [String]?, packID: String?, devicesDir: String,
                      upstreamNames: [String], download: (String) throws -> Data = FrameSource.download(name:),
                      log: (String) -> Void) throws -> String {
        var matches = try FrameSource.framesByColor(for: query, in: upstreamNames)
        if let colorFilter {
            let missing = colorFilter.filter { matches[$0] == nil }
            guard missing.isEmpty else {
                throw AppshotError("colors \(missing) not available; found \(matches.keys.sorted())")
            }
            matches = matches.filter { colorFilter.contains($0.key) }
        }

        let deviceID = packID ?? FrameSource.slug(query)
        let fm = FileManager.default
        // Staged on the studio's volume, so the finished pack moves into devices/ in one
        // rename and a failed fetch leaves nothing there.
        let stagingDir = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                    appropriateFor: URL(fileURLWithPath: devicesDir).deletingLastPathComponent(),
                                    create: true)
        defer { try? fm.removeItem(at: stagingDir) }
        let packDir = join(stagingDir.path, deviceID)
        try fm.ensureDirectory(packDir)

        var frameSize: [Int]?
        var screenRect: [Int]?
        var colorFiles: [String: String] = [:]
        for (color, name) in matches.sorted(by: { $0.key < $1.key }) {
            log("  ↓ \(name).png")
            let bytes = try download(name)
            let framePath = join(packDir, "frame-\(color).png")
            try bytes.write(to: URL(fileURLWithPath: framePath))
            let frame = try RGBAImage.decode(path: framePath)
            if frameSize == nil {
                frameSize = [frame.width, frame.height]
                log("  … measuring the screen cutout")
                let (rect, mask) = try measure(frame)
                screenRect = rect
                try mask.encodeRGBA(path: join(packDir, "hole-mask.png"))
            } else if frameSize != [frame.width, frame.height] {
                throw AppshotError("'\(name)' is \(frame.width)×\(frame.height), expected \(frameSize!)")
            }
            colorFiles[color] = "frame-\(color).png"
        }

        let defaultColor = colorFiles["silver"] != nil ? "silver" : colorFiles.keys.sorted()[0]
        let spec = DeviceSpec(frameSize: frameSize!, screen: screenRect!, mask: "hole-mask.png",
                              colors: colorFiles, default: defaultColor)
        try writeJSON(spec, to: join(packDir, "device.json"))
        try fm.ensureDirectory(devicesDir)
        _ = try fm.replaceItemAt(URL(fileURLWithPath: join(devicesDir, deviceID)),
                                 withItemAt: URL(fileURLWithPath: packDir))
        log("\ndevices/\(deviceID): frame \(frameSize![0])×\(frameSize![1]), "
            + "screen \(screenRect!), colors \(colorFiles.keys.sorted()), default '\(defaultColor)'")
        return deviceID
    }

    /// The alpha channel is flood-filled from the canvas corners; the transparent
    /// region NOT reachable from outside is the screen hole.
    static func measure(_ frame: RGBAImage) throws -> (screen: [Int], mask: RGBAImage) {
        let width = frame.width, height = frame.height
        var transparent = [Bool](repeating: false, count: width * height)
        for index in 0..<(width * height) {
            transparent[index] = frame.pixels[index].a < alphaThreshold
        }

        var outside = [Bool](repeating: false, count: width * height)
        var stack = [Int]()
        func seed(_ index: Int) {
            if transparent[index] && !outside[index] {
                outside[index] = true
                stack.append(index)
            }
        }
        for x in 0..<width {
            seed(x)
            seed((height - 1) * width + x)
        }
        for y in 0..<height {
            seed(y * width)
            seed(y * width + width - 1)
        }
        while let index = stack.popLast() {
            let x = index % width
            if index >= width { seed(index - width) }
            if index < width * (height - 1) { seed(index + width) }
            if x > 0 { seed(index - 1) }
            if x < width - 1 { seed(index + 1) }
        }

        var minX = width, minY = height, maxX = -1, maxY = -1
        var maskPixels = [PNG.RGBA<UInt8>](repeating: PNG.RGBA(255, 255, 255, 0), count: width * height)
        for index in 0..<(width * height) where transparent[index] && !outside[index] {
            maskPixels[index] = PNG.RGBA(255, 255, 255, 255)
            let x = index % width, y = index / width
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
        }
        guard maxX >= 0 else {
            throw AppshotError("no interior screen cutout found in the frame art")
        }
        return ([minX, minY, maxX - minX + 1, maxY - minY + 1],
                RGBAImage(width: width, height: height, pixels: maskPixels))
    }

    static func installed(devicesDir: String) -> [(id: String, spec: DeviceSpec)] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: devicesDir) else { return [] }
        return entries.sorted().compactMap { entry in
            guard let spec = try? loadJSON(DeviceSpec.self, at: join(devicesDir, entry, "device.json"),
                                           what: "device pack") else { return nil }
            return (entry, spec)
        }
    }
}
