import Foundation
import Testing
@testable import appshot

@Suite struct FrameMatchingTests {
    /// `appshot devices list` as of 2026-09-29 (fastlane/frameit-frames, 280 frames).
    let upstreamNames: [String]

    init() throws {
        let fixture = try #require(Bundle.module.url(forResource: "frameit-frame-names", withExtension: "txt",
                                                      subdirectory: "Fixtures"))
        upstreamNames = try String(contentsOf: fixture, encoding: .utf8)
            .split(separator: "\n").map(String.init)
    }

    @Test func proLeavesOutProMax() throws {
        #expect(try FrameSource.framesByColor(for: "iPhone 17 Pro", in: upstreamNames) == [
            "cosmic-orange": "Apple iPhone 17 Pro Cosmic Orange",
            "deep-blue": "Apple iPhone 17 Pro Deep Blue",
            "silver": "Apple iPhone 17 Pro Silver",
        ])
    }

    @Test func baseModelLeavesOutProAndProMax() throws {
        #expect(try FrameSource.framesByColor(for: "iPhone 17", in: upstreamNames) == [
            "black": "Apple iPhone 17 Black",
            "lavender": "Apple iPhone 17 Lavender",
            "mist-blue": "Apple iPhone 17 Mist Blue",
            "sage": "Apple iPhone 17 Sage",
            "white": "Apple iPhone 17 White",
        ])
    }

    @Test func proMaxKeepsItsColors() throws {
        #expect(try FrameSource.framesByColor(for: "iPhone 17 Pro Max", in: upstreamNames) == [
            "cosmic-orange": "Apple iPhone 17 Pro Max Cosmic Orange",
            "deep-blue": "Apple iPhone 17 Pro Max Deep Blue",
            "silver": "Apple iPhone 17 Pro Max Silver",
        ])
    }

    @Test func iPhone16NeverMatches16e() throws {
        // frameit has no 16e frames yet, so two are added for this check.
        let namesWith16e = upstreamNames + ["Apple iPhone 16e Black", "Apple iPhone 16e White"]
        let iPhone16Frames = try FrameSource.framesByColor(for: "iPhone 16", in: namesWith16e)
        #expect(iPhone16Frames.keys.sorted() == ["black", "pink", "teal", "ultramarine", "white"])
        #expect(iPhone16Frames.values.allSatisfy { !$0.contains("16e") })
        #expect(try FrameSource.framesByColor(for: "iPhone 16e", in: namesWith16e) == [
            "black": "Apple iPhone 16e Black",
            "white": "Apple iPhone 16e White",
        ])
    }

    @Test func iPadProLeavesOutItsSizedModels() throws {
        #expect(try FrameSource.framesByColor(for: "iPad Pro", in: upstreamNames) == [
            "gold": "Apple iPad Pro Gold",
            "silver": "Apple iPad Pro Silver",
            "space-gray": "Apple iPad Pro Space Gray",
        ])
        #expect(try FrameSource.framesByColor(for: "iPad Pro (11-inch)", in: upstreamNames) == [
            "silver": "Apple iPad Pro (11-inch) Silver",
            "space-gray": "Apple iPad Pro (11-inch) Space Gray",
        ])
    }

    @Test func multiWordColorsBecomeOneSlug() throws {
        let iPhone16ProColors = try FrameSource.framesByColor(for: "iPhone 16 Pro", in: upstreamNames).keys.sorted()
        #expect(iPhone16ProColors == ["black-titanium", "desert-titanium", "natural-titanium", "white-titanium"])
    }

    @Test func caseAndSpacingDoNotMatter() throws {
        let colors = try FrameSource.framesByColor(for: "  iphone 17   PRO ", in: upstreamNames).keys.sorted()
        #expect(colors == ["cosmic-orange", "deep-blue", "silver"])
    }

    @Test func everyIPhoneAndIPadFrameBelongsToExactlyOneModel() throws {
        let models = [
            "iPhone 11", "iPhone 11 Pro", "iPhone 11 Pro Max", "iPhone 12", "iPhone 12 Mini", "iPhone 12 Pro",
            "iPhone 12 Pro Max", "iPhone 13", "iPhone 13 Mini", "iPhone 13 Pro", "iPhone 13 Pro Max", "iPhone 14",
            "iPhone 14 Plus", "iPhone 14 Pro", "iPhone 14 Pro Max", "iPhone 16", "iPhone 16 Plus", "iPhone 16 Pro",
            "iPhone 16 Pro Max", "iPhone 17", "iPhone 17 Pro", "iPhone 17 Pro Max", "iPhone 5c", "iPhone 5s",
            "iPhone 6s", "iPhone 6s Plus", "iPhone 7", "iPhone 7 Plus", "iPhone 8", "iPhone 8 Plus", "iPhone SE",
            "iPhone X", "iPhone XR", "iPhone XS", "iPhone XS Max",
            "iPad 10.2", "iPad Air (2019) 2", "iPad Air (2019) 2020", "iPad Mini (2019)", "iPad Pro",
            "iPad Pro (11-inch)", "iPad Pro (12.9-inch) (4th generation)",
        ]
        let framesOfAllModels = try models.flatMap { model in
            try FrameSource.framesByColor(for: model, in: upstreamNames).values
        }
        let iPhoneAndIPadFrames = upstreamNames.filter { $0.hasPrefix("Apple iPhone ") || $0.hasPrefix("Apple iPad ") }
        #expect(framesOfAllModels.sorted() == iPhoneAndIPadFrames.sorted())
    }

    @Test func unknownDeviceListsTheModelsOfItsShorterName() {
        let message = thrownMessage { try FrameSource.framesByColor(for: "iPhone 17 Pr", in: upstreamNames) }
        #expect(message == """
            no frame matches "iPhone 17 Pr" — devices matching "iPhone 17":
              Apple iPhone 17
              Apple iPhone 17 Pro
              Apple iPhone 17 Pro Max
            """)
    }

    @Test func ambiguousNameListsItsModels() {
        let message = thrownMessage { try FrameSource.framesByColor(for: "iPad Air (2019)", in: upstreamNames) }
        #expect(message == """
            "iPad Air (2019)" matches more than one device — pick one:
              Apple iPad Air (2019) 2
              Apple iPad Air (2019) 2020
            """)
        let proMaxMessage = thrownMessage { try FrameSource.framesByColor(for: "Pro Max", in: upstreamNames) }
        #expect(proMaxMessage.hasPrefix("\"Pro Max\" matches more than one device"))
        #expect(proMaxMessage.contains("Apple iPhone 11 Pro Max\n"))
        #expect(proMaxMessage.hasSuffix("Apple iPhone 17 Pro Max"))
    }

    @Test func nameWithNothingCloseSuggestsTheList() {
        let message = thrownMessage { try FrameSource.framesByColor(for: "Nokia 3310", in: upstreamNames) }
        #expect(message == "no frame matches \"Nokia 3310\" — try `appshot devices list`")
    }
}

@Suite struct DevicePackFetchTests {
    let studio: TemporaryDirectory
    let devicesDir: String
    let frameBytes: Data
    let upstreamNames = [
        "Apple iPhone 17 Pro Cosmic Orange", "Apple iPhone 17 Pro Deep Blue", "Apple iPhone 17 Pro Silver",
        "Apple iPhone 17 Pro Max Cosmic Orange", "Apple iPhone 17 Pro Max Deep Blue", "Apple iPhone 17 Pro Max Silver",
    ]

    init() throws {
        studio = try TemporaryDirectory()
        devicesDir = join(studio.path, "devices")
        frameBytes = try Self.frameWithScreenHole(scratchPath: join(studio.path, "frame.png"))
    }

    /// 20×40 bezel art: a 4 px opaque border around a transparent screen hole.
    static func frameWithScreenHole(scratchPath: String) throws -> Data {
        let width = 20, height = 40
        let rgbaBytes = (0..<(width * height)).flatMap { index -> [UInt8] in
            let column = index % width, row = index / width
            let insideHole = (4..<16).contains(column) && (4..<36).contains(row)
            return insideHole ? [0, 0, 0, 0] : [40, 40, 40, 255]
        }
        try RGBAImage(width: width, height: height, rgbaBytes: rgbaBytes).encodeRGBA(path: scratchPath)
        return try Data(contentsOf: URL(fileURLWithPath: scratchPath))
    }

    @Test func fetchInstallsACompletePack() throws {
        let deviceID = try DevicePackBuilder.fetch(query: "iPhone 17 Pro", colorFilter: nil, packID: nil,
                                                   devicesDir: devicesDir, upstreamNames: upstreamNames,
                                                   download: { _ in frameBytes }, log: { _ in })
        #expect(deviceID == "iphone-17-pro")
        let packDir = join(devicesDir, deviceID)
        let spec = try loadJSON(DeviceSpec.self, at: join(packDir, "device.json"), what: "device pack")
        #expect(spec.frameSize == [20, 40])
        #expect(spec.screen == [4, 4, 12, 32])
        #expect(spec.colors.keys.sorted() == ["cosmic-orange", "deep-blue", "silver"])
        #expect(spec.default == "silver")
        #expect(try FileManager.default.contentsOfDirectory(atPath: packDir).sorted() == [
            "device.json", "frame-cosmic-orange.png", "frame-deep-blue.png", "frame-silver.png", "hole-mask.png",
        ])
    }

    @Test func failedDownloadLeavesNothingBehind() throws {
        var downloadCount = 0
        let message = thrownMessage {
            try DevicePackBuilder.fetch(query: "iPhone 17 Pro", colorFilter: nil, packID: nil,
                                        devicesDir: devicesDir, upstreamNames: upstreamNames,
                                        download: { _ in
                                            downloadCount += 1
                                            if downloadCount == 2 { throw AppshotError("connection lost") }
                                            return frameBytes
                                        }, log: { _ in })
        }
        #expect(message == "connection lost")
        #expect(!FileManager.default.fileExists(atPath: devicesDir))
    }

    @Test func failedRefetchKeepsTheInstalledPack() throws {
        _ = try DevicePackBuilder.fetch(query: "iPhone 17 Pro", colorFilter: ["silver"], packID: nil,
                                        devicesDir: devicesDir, upstreamNames: upstreamNames,
                                        download: { _ in frameBytes }, log: { _ in })
        let devicePath = join(devicesDir, "iphone-17-pro", "device.json")
        let installedSpec = try String(contentsOfFile: devicePath, encoding: .utf8)

        let message = thrownMessage {
            try DevicePackBuilder.fetch(query: "iPhone 17 Pro", colorFilter: nil, packID: nil,
                                        devicesDir: devicesDir, upstreamNames: upstreamNames,
                                        download: { _ in throw AppshotError("connection lost") }, log: { _ in })
        }
        #expect(message == "connection lost")
        #expect(try String(contentsOfFile: devicePath, encoding: .utf8) == installedSpec)
        #expect(try FileManager.default.contentsOfDirectory(atPath: join(devicesDir, "iphone-17-pro")).sorted()
            == ["device.json", "frame-silver.png", "hole-mask.png"])
    }
}
