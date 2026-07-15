import Foundation
import PNG

enum FrameSource {
    static let listingURL = "https://api.github.com/repos/fastlane/frameit-frames/contents/latest"
    static let rawBase = "https://raw.githubusercontent.com/fastlane/frameit-frames/gh-pages/latest/"

    struct Entry: Decodable { var name: String }

    static func upstreamNames() throws -> [String] {
        let entries = try JSONDecoder().decode([Entry].self, from: httpGet(listingURL))
        return entries.compactMap { entry in
            entry.name.hasSuffix(".png") ? String(entry.name.dropLast(4)) : nil
        }.sorted()
    }

    /// frameit names look like "Apple iPhone 17 Pro Max Silver" — the part after
    /// the device query is the color.
    static func matches(in names: [String], query: String) -> [String: String] {
        var found: [String: String] = [:]
        for name in names {
            guard let range = name.range(of: query, options: [.caseInsensitive]) else { continue }
            let colorText = name[range.upperBound...].trimmingCharacters(in: .whitespaces)
            found[slug(colorText.isEmpty ? "standard" : colorText)] = name
        }
        return found
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

enum DevicePackBuilder {
    static let alphaThreshold: UInt8 = 16

    static func fetch(query: String, colorFilter: [String]?, packID: String?,
                      devicesDir: String, log: (String) -> Void) throws -> String {
        let names = try FrameSource.upstreamNames()
        var matches = FrameSource.matches(in: names, query: query)
        guard !matches.isEmpty else {
            throw AppshotError("no frame matches \"\(query)\" — try `appshot devices list`")
        }
        if let colorFilter {
            let missing = colorFilter.filter { matches[$0] == nil }
            guard missing.isEmpty else {
                throw AppshotError("colors \(missing) not available; found \(matches.keys.sorted())")
            }
            matches = matches.filter { colorFilter.contains($0.key) }
        }

        let deviceID = packID ?? FrameSource.slug(query)
        let packDir = join(devicesDir, deviceID)
        try FileManager.default.ensureDirectory(packDir)

        var frameSize: [Int]?
        var screenRect: [Int]?
        var colorFiles: [String: String] = [:]
        for (color, name) in matches.sorted(by: { $0.key < $1.key }) {
            log("  ↓ \(name).png")
            let bytes = try FrameSource.download(name: name)
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
