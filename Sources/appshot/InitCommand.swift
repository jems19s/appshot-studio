import ArgumentParser
import Foundation

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Scaffold apps/<name>/ — device, screenshots, locales, captions, theme.",
        discussion: "Without options it runs an interactive wizard. With --name it takes every answer from "
            + "options instead, for scripts, CI and coding agents.")

    @Option(help: "studio root (default: current directory)")
    var root: String?

    @Option(name: .customLong("name"), help: "app name — skips the wizard; needs --device and --screenshots")
    var appName: String?

    @Option(help: "device as frameit names it, e.g. \"iPhone 17 Pro Max\" (fetched when not installed)")
    var device: String?

    @Option(help: "device color, e.g. \"deep-blue\" or \"Deep Blue\" (default: the device pack's default)")
    var color: String?

    @Option(help: "output size WIDTHxHEIGHT (default: the device's screen size)")
    var size: String?

    @Option(help: "folder with your screenshots (PNG)")
    var screenshots: String?

    @Option(name: .customLong("locale"), help: "locale to create captions for (repeatable, default: en)")
    var locales: [String] = []

    @Option(name: .customLong("caption"), help: "caption for each screenshot, in file name order (repeatable)")
    var captions: [String] = []

    @Flag(help: "replace an existing apps/<name>/config.json")
    var overwrite = false

    private enum Metrics {
        static let captionSpace = 440
        static let deviceWidthShare = 1120.0 / 1320
        static let bottomMarginShare = 0.045
    }

    private static let defaultMeshColors = [
        "#e8ecf4", "#dfe7f7", "#f3f0ea",
        "#d5dcef", "#eef0f2", "#e2e6ee",
        "#e9e4f2", "#d9e2ef", "#f2f2ea",
    ]

    private struct Draft {
        var name = ""
        var deviceID: String?
        var deviceColor: String?
        var width = 0, height = 0
        var folder: String?
        var files: [String] = []
        var slots: [AppConfig.Slot] = []
        var titles: [String] = []
        var locales: [String] = []
        var accent = "#4f7df9"
        var headline = "#181a20"
        var background: AppConfig.Background?
    }

    private enum Step {
        case name, device, color, size, screenshots, captions, locales, accent, headline, background, finished
    }

    func validate() throws {
        let answersGiven = device != nil || color != nil || size != nil || screenshots != nil
            || !locales.isEmpty || !captions.isEmpty || overwrite
        if appName == nil && answersGiven {
            throw ValidationError("add --name to skip the wizard, or drop the options to run it")
        }
        if appName != nil && (device == nil || screenshots == nil) {
            throw ValidationError("--name skips the wizard, so it also needs --device and --screenshots")
        }
    }

    func run() throws {
        let root = Studio.root(root)
        if let appName {
            try scaffold(appName: appName, root: root)
        } else {
            try runWizard(root: root)
        }
    }

    private func runWizard(root: String) throws {
        let fm = FileManager.default
        print("appshot init — answers become apps/<name>/config.json; everything is editable later.")
        print(Prompt.dim + (Prompt.interactive
            ? "esc goes back a step."
            : "\"<\" on text prompts and \"0\" on menus goes back a step.") + Prompt.reset + "\n")

        let devicesDir = join(root, "devices")
        var upstreamNames: [String]?
        var draft = Draft()
        var step = Step.name
        var backing = false

        while step != .finished {
            switch step {
            case .name:
                var name = ""
                while name.isEmpty {
                    name = FrameSource.slug(Prompt.text("App name",
                                                        defaultValue: draft.name.isEmpty ? nil : draft.name) ?? "")
                }
                if name != draft.name, fm.fileExists(atPath: join(root, "apps", name, "config.json")) {
                    guard Prompt.confirm("apps/\(name) already exists — overwrite its config?",
                                         defaultValue: false) == true else { continue }
                }
                draft.name = name
                step = .device; backing = false

            case .device:
                if let id = try pickDevice(devicesDir: devicesDir, upstreamNames: &upstreamNames,
                                           current: draft.deviceID) {
                    draft.deviceID = id
                    step = .color; backing = false
                } else {
                    step = .name; backing = true
                }

            case .color:
                let spec = try loadJSON(DeviceSpec.self,
                                        at: join(devicesDir, draft.deviceID!, "device.json"),
                                        what: "device pack")
                let colorKeys = spec.colors.keys.sorted()
                if colorKeys.count == 1 {
                    if backing {
                        step = .device
                    } else {
                        draft.deviceColor = colorKeys[0]
                        step = .size
                    }
                    continue
                }
                let defaultIndex = colorKeys.firstIndex(of: spec.default ?? "") ?? 0
                let ordered = [colorKeys[defaultIndex]] + colorKeys.enumerated()
                    .filter { $0.offset != defaultIndex }.map(\.element)
                let initial = draft.deviceColor.flatMap { ordered.firstIndex(of: $0) } ?? 0
                if let choice = Prompt.select("Device color", options: ordered,
                                              initial: initial, canGoBack: true) {
                    draft.deviceColor = ordered[choice]
                    step = .size; backing = false
                } else {
                    step = .device; backing = true
                }

            case .size:
                let spec = try loadJSON(DeviceSpec.self, at: join(devicesDir, draft.deviceID!, "device.json"),
                                        what: "device pack")
                if let (width, height) = pickOutputSize(screenSize: (spec.screen[2], spec.screen[3]),
                                                        current: draft.width > 0 ? (draft.width, draft.height) : nil) {
                    draft.width = width; draft.height = height
                    step = .screenshots; backing = false
                } else {
                    step = .color; backing = true
                }

            case .screenshots:
                if let (folder, files) = pickScreenshotFolder(defaultFolder: draft.folder) {
                    if files != draft.files || folder != draft.folder {
                        draft.files = files
                        (draft.slots, draft.titles) = makeSlots(files: files)
                    }
                    draft.folder = folder
                    try copyAssets(files: files, from: folder,
                                   to: join(root, "apps", draft.name, "assets"))
                    step = .captions; backing = false
                } else {
                    step = .size; backing = true
                }

            case .captions:
                if !backing {
                    print(Prompt.dim + "Captions: *word or phrase* renders in the accent color; \\n breaks the line." + Prompt.reset)
                }
                var index = backing ? draft.titles.count - 1 : 0
                while true {
                    if index == draft.slots.count { step = .locales; backing = false; break }
                    if index < 0 { step = .screenshots; backing = true; break }
                    let existing = draft.titles[index]
                    if let title = Prompt.text("Caption for \(draft.slots[index].name)",
                                               defaultValue: existing.isEmpty ? nil
                                                   : existing.replacingOccurrences(of: "\n", with: "\\n"),
                                               canGoBack: true) {
                        draft.titles[index] = title.replacingOccurrences(of: "\\n", with: "\n")
                        index += 1
                    } else {
                        index -= 1
                    }
                }

            case .locales:
                if let answer = Prompt.text("Locales (comma-separated)",
                                            defaultValue: draft.locales.isEmpty ? "en"
                                                : draft.locales.joined(separator: ", "),
                                            canGoBack: true) {
                    let locales = answer.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    draft.locales = locales.isEmpty ? ["en"] : locales
                    step = .accent; backing = false
                } else {
                    step = .captions; backing = true
                }

            case .accent:
                if let color = pickColor("Accent color (hex)", defaultValue: draft.accent) {
                    draft.accent = color
                    step = .headline; backing = false
                } else {
                    step = .locales; backing = true
                }

            case .headline:
                if let color = pickColor("Headline color (hex)", defaultValue: draft.headline) {
                    draft.headline = color
                    step = .background; backing = false
                } else {
                    step = .accent; backing = true
                }

            case .background:
                if let background = pickBackground(current: draft.background) {
                    draft.background = background
                    step = .finished
                } else {
                    step = .headline; backing = true
                }

            case .finished:
                break
            }
        }

        try write(draft: draft, root: root)
        printNotes(draft: draft)
        if Prompt.confirm("Render now?") == true {
            print("\nRendering '\(draft.name)' …")
            try RenderEngine.renderApp(app: draft.name, root: root, onlyLocales: [], onlySlots: [],
                                       chromeOverride: nil)
        } else {
            print("\nWhen ready: appshot render --app \(draft.name)")
        }
    }

    private func scaffold(appName: String, root: String) throws {
        let name = FrameSource.slug(appName)
        guard !name.isEmpty else { throw AppshotError("--name needs at least one letter or digit") }
        if !overwrite, FileManager.default.fileExists(atPath: join(root, "apps", name, "config.json")) {
            throw AppshotError("apps/\(name) already exists — pass --overwrite to replace its config")
        }

        let devicesDir = join(root, "devices")
        let deviceID = try installedOrFetchedDevice(named: device!, devicesDir: devicesDir)
        let spec = try loadJSON(DeviceSpec.self, at: join(devicesDir, deviceID, "device.json"),
                                what: "device pack")
        let deviceColor = color.map(FrameSource.slug) ?? spec.default ?? spec.colors.keys.sorted()[0]
        guard spec.colors[deviceColor] != nil else {
            throw AppshotError("devices/\(deviceID) has no '\(deviceColor)' frame; it has "
                + spec.colors.keys.sorted().joined(separator: ", "))
        }

        let outputSize = try size.map(parsedOutputSize) ?? (width: spec.screen[2], height: spec.screen[3])

        let folder = screenshotFolderPath(screenshots!)
        let files = pngFiles(in: folder)
        guard !files.isEmpty else { throw AppshotError("no PNGs in \(folder)") }
        guard captions.count <= files.count else {
            throw AppshotError("\(captions.count) captions for \(files.count) screenshots: "
                + files.joined(separator: ", "))
        }

        var draft = Draft()
        draft.name = name
        draft.deviceID = deviceID
        draft.deviceColor = deviceColor
        (draft.width, draft.height) = outputSize
        draft.folder = folder
        draft.files = files
        (draft.slots, draft.titles) = makeSlots(files: files)
        for (index, caption) in captions.enumerated() {
            draft.titles[index] = caption.replacingOccurrences(of: "\\n", with: "\n")
        }
        draft.locales = locales.isEmpty ? ["en"] : locales
        draft.background = .init(type: "mesh", colors: Self.defaultMeshColors)

        try copyAssets(files: files, from: folder, to: join(root, "apps", name, "assets"))
        try write(draft: draft, root: root)
        printNotes(draft: draft)
        print("\nNext: appshot render --app \(name)")
    }

    private func installedOrFetchedDevice(named deviceName: String, devicesDir: String) throws -> String {
        let deviceID = FrameSource.slug(deviceName)
        let installedDeviceIDs = DevicePackBuilder.installed(devicesDir: devicesDir).map(\.id)
        if installedDeviceIDs.contains(deviceID) { return deviceID }
        print("Fetching \(deviceName) (frames come from fastlane/frameit-frames)…")
        return try DevicePackBuilder.fetch(query: deviceName, colorFilter: nil, packID: nil,
                                           devicesDir: devicesDir,
                                           upstreamNames: FrameSource.upstreamNames()) { print($0) }
    }

    private func parsedOutputSize(_ answer: String) throws -> (width: Int, height: Int) {
        let sides = answer.lowercased().split { $0 == "x" || $0 == "×" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard sides.count == 2 else { throw AppshotError("Expected --size WIDTHxHEIGHT, e.g. 1320x2868.") }
        return (try NumberRule.pixelSize.validated(sides[0]), try NumberRule.pixelSize.validated(sides[1]))
    }

    private func printNotes(draft: Draft) {
        print("""

        Done. Notes:
          · System fonts are used by default — point config.json "fonts" at your own files to brand it.
          · Every locale starts with the \(draft.locales[0]) captions — translate apps/\(draft.name)/captions/<locale>.json.
          · Device size/position = layout.deviceWidth/deviceTop in config.json (slots can override per shot).
          · Theme and background live there too — tweak, then re-run render.
        """)
    }

    private func write(draft: Draft, root: String) throws {
        let appDir = join(root, "apps", draft.name)
        let spec = try loadJSON(DeviceSpec.self, at: join(root, "devices", draft.deviceID!, "device.json"),
                                what: "device pack")
        let config = AppConfig(
            app: draft.name,
            device: draft.deviceID!,
            deviceColor: draft.deviceColor,
            output: .init(width: draft.width, height: draft.height),
            layout: .init(deviceWidth: deviceWidthFittingCanvas(width: draft.width, height: draft.height,
                                                                frameSize: spec.frameSize),
                          deviceTop: Metrics.captionSpace),
            fonts: nil,
            locales: draft.locales,
            theme: ["accent": draft.accent, "headlineColor": draft.headline],
            background: draft.background!,
            slots: draft.slots)
        try FileManager.default.ensureDirectory(join(appDir, "captions"))
        try writeJSON(config, to: join(appDir, "config.json"))
        print("  ✓ apps/\(draft.name)/config.json")
        for locale in draft.locales {
            let captions = Dictionary(uniqueKeysWithValues: zip(draft.slots.map(\.caption), draft.titles))
                .mapValues { CaptionEntry.fields(["title": $0]) }
            try writeJSON(captions, to: join(appDir, "captions", "\(locale).json"))
            print("  ✓ apps/\(draft.name)/captions/\(locale).json")
        }
        try EmbeddedTemplate.bootstrap(root: root)
    }

    private func pickDevice(devicesDir: String, upstreamNames: inout [String]?,
                            current: String?) throws -> String? {
        while true {
            let installed = DevicePackBuilder.installed(devicesDir: devicesDir)
            if installed.isEmpty {
                print("No device packs installed yet — fetching one (frames come from fastlane/frameit-frames).")
                return try fetchFlow(devicesDir: devicesDir, upstreamNames: &upstreamNames)
            }
            let options = installed.map { "\($0.id)  (\($0.spec.colors.keys.sorted().joined(separator: ", ")))" }
                + ["Fetch a different device…"]
            let initial = installed.firstIndex { $0.id == current } ?? 0
            guard let choice = Prompt.select("Device", options: options,
                                             initial: initial, canGoBack: true) else { return nil }
            if choice < installed.count { return installed[choice].id }
            if let fetched = try fetchFlow(devicesDir: devicesDir, upstreamNames: &upstreamNames) {
                return fetched
            }
        }
    }

    private func fetchFlow(devicesDir: String, upstreamNames: inout [String]?) throws -> String? {
        if upstreamNames == nil {
            print("Loading the upstream frame list…")
            upstreamNames = try FrameSource.upstreamNames()
        }
        let names = upstreamNames!
        while true {
            guard let query = Prompt.text("Device name", defaultValue: "iPhone 17 Pro Max",
                                          canGoBack: true) else { return nil }
            let framesByColor: [String: String]
            do {
                framesByColor = try FrameSource.framesByColor(for: query, in: names)
            } catch {
                print(error)
                continue
            }
            let colors = framesByColor.keys.sorted()
            var chosen = colors
            if colors.count > 1 {
                guard let picked = Prompt.multiSelect("Colors to download", options: colors,
                                                      canGoBack: true) else { continue }
                chosen = colors.enumerated().filter { picked.contains($0.offset) }.map(\.element)
            }
            return try DevicePackBuilder.fetch(query: query, colorFilter: chosen, packID: nil,
                                               devicesDir: devicesDir, upstreamNames: names) { print($0) }
        }
    }

    /// The device takes the width an iPhone set uses, unless that would push it past the bottom of the
    /// canvas, as on landscape screens: then it shrinks to fit between the caption and the bottom margin.
    private func deviceWidthFittingCanvas(width: Int, height: Int, frameSize: [Int]) -> Int {
        let frameHeightPerWidth = Double(frameSize[1]) / Double(frameSize[0])
        let widthByCanvas = Double(width) * Metrics.deviceWidthShare
        let heightBelowCaption = Double(height - Metrics.captionSpace) - Double(height) * Metrics.bottomMarginShare
        return Int(min(widthByCanvas, heightBelowCaption / frameHeightPerWidth).rounded())
    }

    private func pickOutputSize(screenSize: (width: Int, height: Int), current: (Int, Int)?) -> (Int, Int)? {
        let options: [(label: String, size: (Int, Int)?)] = [
            ("\(screenSize.width) × \(screenSize.height) — the device's screen size", screenSize),
            ("Custom…", nil),
        ]
        while true {
            let initial = current.flatMap { size in
                options.firstIndex { $0.size ?? (0, 0) == size }
            } ?? 0
            guard let choice = Prompt.select("Output size", options: options.map(\.label),
                                             initial: initial, canGoBack: true) else { return nil }
            if let size = options[choice].size { return size }
            guard let width = pickNumber("Width (px)", defaultValue: current?.0 ?? screenSize.width,
                                         rule: .pixelSize) else { continue }
            guard let height = pickNumber("Height (px)", defaultValue: current?.1 ?? screenSize.height,
                                          rule: .pixelSize) else { continue }
            return (width, height)
        }
    }

    private func pickScreenshotFolder(defaultFolder: String?) -> (String, [String])? {
        while true {
            guard let answer = Prompt.text("Folder with your screenshots (PNG)",
                                           defaultValue: defaultFolder ?? ".",
                                           canGoBack: true) else { return nil }
            let folder = screenshotFolderPath(answer)
            let files = pngFiles(in: folder)
            if files.isEmpty {
                print("No PNGs in \(folder) — try another folder.")
                continue
            }
            print("Found \(files.count):\n  " + files.joined(separator: "\n  "))
            if Prompt.confirm("Use these?", canGoBack: true) == true { return (folder, files) }
        }
    }

    private func screenshotFolderPath(_ answer: String) -> String {
        URL(fileURLWithPath: (answer as NSString).expandingTildeInPath).standardizedFileURL.path
    }

    private func pngFiles(in folder: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return entries.filter { $0.lowercased().hasSuffix(".png") && !$0.hasPrefix(".") }.sorted()
    }

    private func makeSlots(files: [String]) -> ([AppConfig.Slot], [String]) {
        var slots: [AppConfig.Slot] = []
        var captionKeys = Set<String>()
        for (index, file) in files.enumerated() {
            let stem = FrameSource.slug(String(file.dropLast(4)))
            var captionKey = stem
            var suffix = 2
            while captionKeys.contains(captionKey) {
                captionKey = "\(stem)-\(suffix)"
                suffix += 1
            }
            captionKeys.insert(captionKey)
            slots.append(.init(name: String(format: "%02d-", index + 1) + stem,
                               template: EmbeddedTemplate.defaultName,
                               screenshot: file, tilt: 0, caption: captionKey))
        }
        return (slots, [String](repeating: "", count: files.count))
    }

    private func copyAssets(files: [String], from folder: String, to assetsDir: String) throws {
        let fm = FileManager.default
        try fm.ensureDirectory(assetsDir)
        for file in files {
            let destination = join(assetsDir, file)
            if fm.fileExists(atPath: destination) { try fm.removeItem(atPath: destination) }
            try fm.copyItem(atPath: join(folder, file), toPath: destination)
        }
    }

    private func pickColor(_ label: String, defaultValue: String) -> String? {
        while true {
            guard let answer = Prompt.text(label, defaultValue: defaultValue,
                                           canGoBack: true) else { return nil }
            if (try? BackgroundRenderer.rgb(answer)) != nil { return answer }
            print("Expected #rrggbb.")
        }
    }

    private func pickNumber(_ label: String, defaultValue: Int, rule: NumberRule) -> Int? {
        while true {
            guard let answer = Prompt.text(label, defaultValue: String(defaultValue),
                                           canGoBack: true) else { return nil }
            do {
                return try rule.validated(answer)
            } catch {
                print(error)
            }
        }
    }

    private func pickBackground(current: AppConfig.Background?) -> AppConfig.Background? {
        let labels = [
            "Mesh gradient (soft default palette — edit colors later in config.json)",
            "Solid color",
            "Linear gradient",
            "Ready-made image from assets/",
        ]
        let types = ["mesh", "solid", "linear", "image"]
        while true {
            let initial = current.flatMap { types.firstIndex(of: $0.type ?? "mesh") } ?? 0
            guard let choice = Prompt.select("Background", options: labels,
                                             initial: initial, canGoBack: true) else { return nil }
            switch choice {
            case 1:
                guard let color = pickColor("Color (hex)",
                                            defaultValue: current?.color ?? "#f2f4f8") else { continue }
                return .init(type: "solid", color: color)
            case 2:
                guard let answer = Prompt.text("Colors from start to end (comma-separated hex)",
                                               defaultValue: current?.stops?.joined(separator: ",")
                                                   ?? "#e8ecf4,#d5dcef",
                                               canGoBack: true) else { continue }
                let stops = answer.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { (try? BackgroundRenderer.rgb($0)) != nil }
                guard stops.count >= 2 else {
                    print("Need at least two valid #rrggbb colors.")
                    continue
                }
                guard let angle = pickNumber("Angle (degrees, 90 = top→bottom)",
                                             defaultValue: Int(current?.angle ?? 90),
                                             rule: .gradientAngle) else { continue }
                return .init(type: "linear", stops: stops, angle: Double(angle))
            case 3:
                guard let file = Prompt.text("File name (drop it into assets/ before rendering)",
                                             defaultValue: current?.file,
                                             canGoBack: true) else { continue }
                return .init(type: "image", file: file)
            default:
                return .init(type: "mesh", colors: current?.colors ?? Self.defaultMeshColors)
            }
        }
    }
}

struct NumberRule {
    static let pixelSize = NumberRule(minimum: 1, maximum: nil)
    static let gradientAngle = NumberRule(minimum: -360, maximum: 360)

    let minimum: Int
    let maximum: Int?

    func validated(_ answer: String) throws -> Int {
        guard let number = Int(answer), number >= minimum, number <= (maximum ?? number) else {
            throw AppshotError(maximum.map { "Expected a whole number from \(minimum) to \($0)." }
                ?? "Expected a whole number of \(minimum) or more.")
        }
        return number
    }
}
