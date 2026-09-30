import Foundation
import Testing
@testable import appshot

@Suite struct DefaultAppTests {
    let studio: TemporaryDirectory

    init() throws {
        studio = try TemporaryDirectory()
    }

    func addApp(_ name: String) throws {
        let appDir = join(studio.path, "apps", name)
        try FileManager.default.ensureDirectory(appDir)
        try "{}".write(toFile: join(appDir, "config.json"), atomically: true, encoding: .utf8)
    }

    @Test func rendersTheOnlyApp() throws {
        try addApp("plants")
        try FileManager.default.ensureDirectory(join(studio.path, "apps", "sketches-without-config"))
        #expect(try Studio.onlyApp(root: studio.path) == "plants")
    }

    @Test func severalAppsNeedAnExplicitChoice() throws {
        try addApp("recipes")
        try addApp("plants")
        #expect(thrownMessage { try Studio.onlyApp(root: studio.path) }
            == "several apps in \(join(studio.path, "apps")): plants, recipes — pick one with --app <name>")
    }

    @Test func emptyStudioPointsToInit() {
        #expect(thrownMessage { try Studio.onlyApp(root: studio.path) }
            == "no app in \(join(studio.path, "apps")) yet — create one with `appshot init`")
    }
}

@Suite struct NumberRuleTests {
    @Test(arguments: ["-360", "-90", "0", "45", "360"])
    func gradientAngleAcceptsZeroAndNegativeDegrees(answer: String) throws {
        #expect(try NumberRule.gradientAngle.validated(answer) == Int(answer))
    }

    @Test(arguments: ["-361", "361", "ninety", "12.5"])
    func gradientAngleExplainsARejection(answer: String) {
        #expect(thrownMessage { try NumberRule.gradientAngle.validated(answer) }
            == "Expected a whole number from -360 to 360.")
    }

    @Test func pixelSizesStayPositive() throws {
        #expect(try NumberRule.pixelSize.validated("2868") == 2868)
        for answer in ["0", "-1320", "wide"] {
            #expect(thrownMessage { try NumberRule.pixelSize.validated(answer) }
                == "Expected a whole number of 1 or more.")
        }
    }
}
