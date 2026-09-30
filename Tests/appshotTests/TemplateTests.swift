import Foundation
import Testing
@testable import appshot

@Suite struct EmbeddedTemplateTests {
    @Test func bootstrapWritesTheTemplatesInTheRepository() throws {
        let studio = try TemporaryDirectory()
        try EmbeddedTemplate.bootstrap(root: studio.path)
        let repositoryTemplates = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("templates")
        for name in ["caption-top", "caption-bottom"] {
            let bootstrapped = try String(contentsOfFile: join(studio.path, "templates", "\(name).html"),
                                          encoding: .utf8)
            let inRepository = try String(contentsOf: repositoryTemplates.appendingPathComponent("\(name).html"),
                                          encoding: .utf8)
            #expect(bootstrapped == inRepository,
                    "EmbeddedTemplate.swift is out of sync with templates/\(name).html")
        }
    }
}

@Suite struct CaptionFitTests {
    @Test func isOffByDefault() throws {
        let captionFit = try CaptionFit(theme: TemplateEngine.themeDefaults)
        #expect(!captionFit.shrinks)
        #expect(captionFit.minPercent == 70)
    }

    @Test func turnsOnWithShrink() throws {
        var theme = TemplateEngine.themeDefaults
        theme["captionFit"] = "shrink"
        theme["captionMinScale"] = "80%"
        let captionFit = try CaptionFit(theme: theme)
        #expect(captionFit.shrinks)
        #expect(captionFit.minPercent == 80)
    }

    @Test(arguments: [
        ("captionFit", "on", "theme.captionFit is \"on\" — expected \"none\" or \"shrink\""),
        ("captionMinScale", "0.7", "theme.captionMinScale must be a whole percentage from 1% to 100%, e.g. \"70%\""),
        ("captionMinScale", "0%", "theme.captionMinScale must be a whole percentage from 1% to 100%, e.g. \"70%\""),
        ("captionFitGap", "2em", "theme.captionFitGap must be in px, e.g. \"40px\""),
    ])
    func rejectsInvalidSettings(key: String, value: String, message: String) {
        var theme = TemplateEngine.themeDefaults
        theme[key] = value
        #expect(thrownMessage { try CaptionFit(theme: theme) } == message)
    }

    @Test func readsWhatThePageReported() {
        #expect(CaptionFit.outcome(pageDOM: "<html><head></head><body data-caption-fit=\"87\">")
            == .scaled(percent: 87))
        #expect(CaptionFit.outcome(pageDOM: "<html><head></head><body data-caption-fit=\"overlaps\">")
            == .overlapsAtMinScale)
        #expect(CaptionFit.outcome(pageDOM: "<html><head></head><body><div data-caption-fit=\"87\">")
            == .notReported)
        #expect(CaptionFit.outcome(pageDOM: "") == .notReported)
    }
}
