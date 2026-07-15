import ArgumentParser
import Foundation

@main
struct Appshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appshot",
        abstract: "Config-driven App Store screenshot renderer.",
        discussion: "Frames real app screenshots inside device bezels with localized captions "
            + "over generated backgrounds — HTML/CSS layouts rasterized by headless Chrome.",
        version: "1.0.0",
        subcommands: [InitCommand.self, RenderCommand.self, DevicesCommand.self])
}

struct RenderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Render App Store screenshots for an app in apps/<app>/.")

    @Option(help: "app folder under apps/")
    var app: String = "demo"

    @Option(name: .customLong("locale"), help: "render only this locale (repeatable)")
    var locales: [String] = []

    @Option(name: .customLong("slot"), help: "render only this slot (repeatable)")
    var slots: [String] = []

    @Option(help: "path to the Chrome/Chromium binary (or set $CHROME)")
    var chrome: String?

    @Option(help: "studio root (default: current directory)")
    var root: String?

    func run() throws {
        print("Rendering '\(app)' …")
        try RenderEngine.renderApp(app: app, root: Studio.root(root),
                                   onlyLocales: locales, onlySlots: slots, chromeOverride: chrome)
    }
}

struct DevicesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devices",
        abstract: "List, fetch and inspect device bezel packs.",
        subcommands: [Installed.self, List.self, Fetch.self],
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

        @Option(help: "comma-separated color slugs to fetch (default: all)")
        var colors: String?

        @Option(help: "device pack folder name (default: slug of the device name)")
        var id: String?

        @Option(help: "studio root (default: current directory)")
        var root: String?

        func run() throws {
            let filter = colors?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            _ = try DevicePackBuilder.fetch(query: device, colorFilter: filter, packID: id,
                                            devicesDir: join(Studio.root(root), "devices")) { print($0) }
        }
    }
}
