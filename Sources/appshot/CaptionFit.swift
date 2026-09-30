import Foundation

/// Caption auto-fit, set in `theme`: with `captionFit` "shrink", the caption templates shrink
/// title and subtitle together until they keep `captionFitGap` clear of the device, never below
/// `captionMinScale`, and leave the outcome in `<body data-caption-fit>` for the tool to read.
struct CaptionFit {
    enum Outcome: Equatable {
        case scaled(percent: Int)
        case overlapsAtMinScale
        case notReported
    }

    let shrinks: Bool
    let minPercent: Int

    init(theme: [String: String]) throws {
        switch theme["captionFit"] {
        case "none": shrinks = false
        case "shrink": shrinks = true
        case let mode: throw AppshotError("theme.captionFit is \"\(mode ?? "")\" — expected \"none\" or \"shrink\"")
        }
        guard let minScale = theme["captionMinScale"], minScale.hasSuffix("%"),
              let minPercent = Int(minScale.dropLast()), (1...100).contains(minPercent) else {
            throw AppshotError("theme.captionMinScale must be a whole percentage from 1% to 100%, e.g. \"70%\"")
        }
        guard let gap = theme["captionFitGap"], gap.hasSuffix("px"), Double(gap.dropLast(2)) != nil else {
            throw AppshotError("theme.captionFitGap must be in px, e.g. \"40px\"")
        }
        self.minPercent = minPercent
    }

    static func outcome(pageDOM: String) -> Outcome {
        guard let reported = pageDOM.firstMatch(of: #/<body[^>]*\sdata-caption-fit="([^"]*)"/#)?.1 else {
            return .notReported
        }
        if reported == "overlaps" { return .overlapsAtMinScale }
        return Int(reported).map { .scaled(percent: $0) } ?? .notReported
    }
}
