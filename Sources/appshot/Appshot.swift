import ArgumentParser
import Foundation

@main
struct Appshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appshot",
        abstract: "Config-driven App Store screenshot renderer.",
        discussion: "Frames real app screenshots inside device bezels with localized captions "
            + "over generated backgrounds — HTML/CSS layouts rasterized by headless Chrome.",
        version: "1.4.1",
        subcommands: [InitCommand.self, RenderCommand.self, DevicesCommand.self])

    /// Line-buffered even when piped, so CI logs and coding agents see progress as it happens and in order with errors.
    static func main() {
        setvbuf(stdout, nil, _IOLBF, 0)
        main(nil)
    }
}

struct RenderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Render App Store screenshots for an app in apps/<app>/.")

    @Option(help: "app folder under apps/ (default: the only app there)")
    var app: String?

    @Option(name: .customLong("locale"), help: "render only this locale (repeatable)")
    var locales: [String] = []

    @Option(name: .customLong("slot"), help: "render only this slot (repeatable)")
    var slots: [String] = []

    @Option(help: "path to the Chrome/Chromium binary (or set $CHROME)")
    var chrome: String?

    @Option(help: "studio root (default: current directory)")
    var root: String?

    func run() throws {
        let studioRoot = Studio.root(root)
        let appName = try app ?? Studio.onlyApp(root: studioRoot)
        print("Rendering '\(appName)' …")
        try RenderEngine.renderApp(app: appName, root: studioRoot,
                                   onlyLocales: locales, onlySlots: slots, chromeOverride: chrome)
    }
}

struct DevicesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "List, fetch and inspect device bezel packs.",
        subcommands: [Installed.self, List.self, Fetch.self, Add.self],
        defaultSubcommand: Installed.self)

    struct Installed: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "installed",
            abstract: "Show device packs installed under devices/.")

        @Option(help: "studio root (default: current directory)")
        var root: String?

        func run() throws {
            let packs = DevicePackBuilder.installed(devicesDir: join(Studio.root(root), "devices"))
            guard !packs.isEmpty else {
                print("No device packs yet — fetch one:  appshot devices fetch \"iPhone 17 Pro Max\"")
                return
            }
            for pack in packs {
                print("\(pack.id): frame \(pack.spec.frameSize[0])×\(pack.spec.frameSize[1]), "
                    + "screen \(pack.spec.screen), colors \(pack.spec.colors.keys.sorted())")
            }
        }
    }

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List every frame available upstream (fastlane/frameit-frames).")

        func run() throws {
            try FrameSource.upstreamNames().forEach { print($0) }
        }
    }

    struct Fetch: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "fetch",
            abstract: "Download a device's frames and measure them into devices/<id>/.")

        @Argument(help: "device name as frameit knows it, e.g. \"iPhone 17 Pro Max\"")
        var device: String

        @Option(help: "comma-separated colors to fetch, e.g. \"silver,deep-blue\" (default: all)")
        var colors: String?

        @Option(help: "device pack folder name (default: slug of the device name)")
        var id: String?

        @Option(help: "studio root (default: current directory)")
        var root: String?

        func run() throws {
            let filter = colors?.split(separator: ",").map { FrameSource.slug(String($0)) }
            _ = try DevicePackBuilder.fetch(query: device, colorFilter: filter, packID: id,
                                            devicesDir: join(Studio.root(root), "devices"),
                                            upstreamNames: FrameSource.upstreamNames()) { print($0) }
        }
    }

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Make a device pack from frame images you downloaded, e.g. Apple's iPhone Duo bezels.",
            discussion: "Pass one <color>=<frame.png> per color; the first becomes the default. "
                + "The screen cutout is measured automatically, as with fetch.")

        @Argument(help: "device pack folder name under devices/, e.g. iphone-duo")
        var id: String

        @Argument(help: "<color>=<frame.png> for each color, e.g. \"star-white=Star White Inner Landscape.png\"")
        var frames: [String] = []

        @Option(help: "studio root (default: current directory)")
        var root: String?

        func run() throws {
            let frameFiles = try frames.map { argument -> (color: String, path: String) in
                let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                    throw AppshotError("'\(argument)' should be <color>=<frame.png>")
                }
                let path = URL(fileURLWithPath: (parts[1] as NSString).expandingTildeInPath).standardizedFileURL.path
                return (color: parts[0], path: path)
            }
            _ = try DevicePackBuilder.add(packID: id, frameFiles: frameFiles,
                                          devicesDir: join(Studio.root(root), "devices")) { print($0) }
        }
    }
}
