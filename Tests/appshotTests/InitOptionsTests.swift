import ArgumentParser
import Foundation
import Testing
@testable import appshot

@Suite struct InitOptionsTests {
    let studio: TemporaryDirectory
    let screenshotsDir: String

    init() throws {
        studio = try TemporaryDirectory()
        let packDir = join(studio.path, "devices", "iphone-17-pro-max")
        try FileManager.default.ensureDirectory(packDir)
        let spec = DeviceSpec(frameSize: [1470, 3000], screen: [75, 66, 1320, 2868], mask: "hole-mask.png",
                              colors: ["silver": "frame-silver.png", "deep-blue": "frame-deep-blue.png"],
                              default: "silver")
        try writeJSON(spec, to: join(packDir, "device.json"))

        screenshotsDir = join(studio.path, "shots")
        try FileManager.default.ensureDirectory(screenshotsDir)
        for file in ["search.png", "home.png", ".hidden.png", "notes.txt"] {
            try Data().write(to: URL(fileURLWithPath: join(screenshotsDir, file)))
        }
    }

    func runInit(_ extraArguments: [String]) throws {
        let arguments = ["--root", studio.path, "--name", "Plants", "--device", "iPhone 17 Pro Max",
                         "--screenshots", screenshotsDir] + extraArguments
        var command = try InitCommand.parse(arguments)
        try command.run()
    }

    @Test func scaffoldsAnAppWithoutTheWizard() throws {
        try runInit(["--color", "deep-blue", "--locale", "en-US", "--locale", "de-DE",
                     "--caption", "Every plant,\\n*happily watered*"])

        let appDir = join(studio.path, "apps", "plants")
        let config = try loadJSON(AppConfig.self, at: join(appDir, "config.json"), what: "config")
        #expect(config.device == "iphone-17-pro-max")
        #expect(config.deviceColor == "deep-blue")
        #expect(config.output.width == 1320 && config.output.height == 2868)
        #expect(config.locales == ["en-US", "de-DE"])
        #expect(config.slots.map(\.name) == ["01-home", "02-search"])
        #expect(config.background.type == "mesh")

        let germanCaptions = try loadJSON([String: CaptionEntry].self,
                                          at: join(appDir, "captions", "de-DE.json"), what: "captions")
        #expect(germanCaptions["home"]?.fields["title"] == "Every plant,\n*happily watered*")
        #expect(germanCaptions["search"]?.fields["title"] == "")
        #expect(FileManager.default.fileExists(atPath: join(appDir, "assets", "search.png")))
    }

    @Test func takesAnExplicitSizeAndDefaultsTheRest() throws {
        try runInit(["--size", "1290x2796"])
        let config = try loadJSON(AppConfig.self, at: join(studio.path, "apps", "plants", "config.json"),
                                  what: "config")
        #expect(config.deviceColor == "silver")
        #expect(config.output.width == 1290 && config.output.height == 2796)
        #expect(config.locales == ["en"])
    }

    @Test func keepsAnExistingAppUnlessToldToOverwrite() throws {
        try runInit([])
        #expect(thrownMessage { try runInit([]) }
            == "apps/plants already exists — pass --overwrite to replace its config")
        try runInit(["--overwrite"])
    }

    @Test func defaultsToTheDeviceScreenAndFitsALandscapeDevice() throws {
        let packDir = join(studio.path, "devices", "iphone-duo")
        try FileManager.default.ensureDirectory(packDir)
        let spec = DeviceSpec(frameSize: [3093, 2247], screen: [120, 120, 2853, 2007], mask: "hole-mask.png",
                              colors: ["star-white": "frame-star-white.png"], default: "star-white")
        try writeJSON(spec, to: join(packDir, "device.json"))

        var command = try InitCommand.parse(["--root", studio.path, "--name", "Duo", "--device", "iphone-duo",
                                             "--screenshots", screenshotsDir])
        try command.run()

        let config = try loadJSON(AppConfig.self, at: join(studio.path, "apps", "duo", "config.json"), what: "config")
        #expect(config.output.width == 2853 && config.output.height == 2007)
        let deviceWidth = try #require(config.layout?.deviceWidth)
        let deviceTop = try #require(config.layout?.deviceTop)
        let deviceBottom = deviceTop + deviceWidth * 2247 / 3093
        #expect(deviceBottom < 2007)
        #expect(deviceWidth < 2853)
    }

    @Test func keepsTheIPhoneLayout() throws {
        try runInit([])
        let config = try loadJSON(AppConfig.self, at: join(studio.path, "apps", "plants", "config.json"),
                                  what: "config")
        #expect(config.layout?.deviceWidth == 1120)
        #expect(config.layout?.deviceTop == 440)
    }

    @Test func acceptsColorNamesAsFrameitPrintsThem() throws {
        try runInit(["--color", "Deep Blue"])
        let config = try loadJSON(AppConfig.self, at: join(studio.path, "apps", "plants", "config.json"),
                                  what: "config")
        #expect(config.deviceColor == "deep-blue")
    }

    @Test func namesTheColorsAPackHas() {
        #expect(thrownMessage { try runInit(["--color", "cosmic-orange"]) }
            == "devices/iphone-17-pro-max has no 'cosmic-orange' frame; it has deep-blue, silver")
    }

    @Test func rejectsMoreCaptionsThanScreenshots() {
        #expect(thrownMessage { try runInit(["--caption", "One", "--caption", "Two", "--caption", "Three"]) }
            == "3 captions for 2 screenshots: home.png, search.png")
    }

    @Test(arguments: [["--device", "iPhone 17 Pro Max"], ["--name", "Plants", "--device", "iPhone 17 Pro Max"]])
    func incompleteOptionsDoNotStartTheWizard(arguments: [String]) {
        #expect(throws: (any Error).self) { try InitCommand.parse(arguments) }
    }
}
