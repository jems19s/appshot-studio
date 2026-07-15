import Foundation

enum TemplateEngine {
    static let themeDefaults: [String: String] = [
        "accent": "#4f7df9",
        "headlineColor": "#181a20",
        "captionTop": "150px",
        "captionBottom": "150px",
        "captionPadding": "0 90px",
        "captionSize": "108px",
        "captionWeight": "800",
        "captionLineHeight": "1.05",
        "captionLetterSpacing": "-0.03em",
        "subtitleSize": "46px",
        "subtitleWeight": "600",
        "subtitleColor": "#4b5563",
        "deviceShadow": "0 56px 90px rgba(10,12,24,.4)",
    ]

    static let systemFontStack = "system-ui,-apple-system,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif"

    static func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
    }

    static func captionHTML(_ text: String) -> String {
        text.components(separatedBy: "*").enumerated().map { index, part in
            let escaped = htmlEscape(part).replacingOccurrences(of: "\n", with: "<br>")
            return index % 2 == 1 ? "<span class=\"accent\">\(escaped)</span>" : escaped
        }.joined()
    }

    static func fontFaces(_ fonts: AppConfig.Fonts?, appDir: String) -> String {
        guard let fonts, let family = fonts.family, let faces = fonts.faces, !faces.isEmpty else { return "" }
        let directory = fonts.dir ?? "."
        let base = directory.hasPrefix("/")
            ? directory
            : URL(fileURLWithPath: join(appDir, directory)).standardizedFileURL.path
        return faces.map { face in
            "@font-face{font-family:'\(family)';font-weight:\(face.weight);"
                + "font-style:\(face.style ?? "normal");src:url('file://\(join(base, face.file))')}"
        }.joined()
    }

    static func fontStack(_ fonts: AppConfig.Fonts?, locale: String) -> String {
        var families: [String] = []
        if let family = fonts?.family { families.append("'\(family)'") }
        if let fallback = fonts?.localeFallbacks?[locale] { families.append("'\(fallback)'") }
        families.append(systemFontStack)
        return families.joined(separator: ",")
    }

    static func fill(_ template: String, with replacements: [String: String]) -> String {
        var page = template
        for (key, value) in replacements {
            page = page.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return page
    }
}
