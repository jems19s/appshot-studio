import Foundation

struct AppConfig: Codable {
    var app: String?
    var device: String
    var deviceColor: String?
    var output: Size
    var layout: Layout?
    var fonts: Fonts?
    var locales: [String]
    var theme: [String: String]?
    var background: Background
    var slots: [Slot]

    struct Size: Codable {
        var width: Int
        var height: Int
    }

    struct Layout: Codable {
        var deviceWidth: Int?
        var deviceTop: Int?
        var deviceLeft: Int?
    }

    struct Fonts: Codable {
        var family: String?
        var dir: String?
        var faces: [Face]?
        var localeFallbacks: [String: String]?

        struct Face: Codable {
            var weight: Int
            var style: String?
            var file: String
        }
    }

    struct Background: Codable {
        var type: String?
        var colors: [String]?
        var scale: Double?
        var blur: Double?
        var color: String?
        var stops: [String]?
        var angle: Double?
        var file: String?
    }

    struct Slot: Codable {
        var name: String
        var template: String
        var screenshot: String
        var tilt: Double?
        var caption: String
        var deviceWidth: Int?
        var deviceTop: Int?
        var deviceLeft: Int?
    }
}

enum CaptionEntry: Codable {
    case title(String)
    case fields([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .title(text)
        } else {
            self = .fields(try container.decode([String: String].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .title(let text): try container.encode(text)
        case .fields(let fields): try container.encode(fields)
        }
    }

    var fields: [String: String] {
        switch self {
        case .title(let text): return ["title": text]
        case .fields(let fields): return fields
        }
    }
}

struct DeviceSpec: Codable {
    var frameSize: [Int]
    var screen: [Int]
    var mask: String
    var colors: [String: String]
    var `default`: String?
}
