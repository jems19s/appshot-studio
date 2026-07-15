import Foundation

enum RenderEngine {
    static func renderApp(app: String, root: String, onlyLocales: [String], onlySlots: [String],
                          chromeOverride: String?) throws {
        let fm = FileManager.default
        let appDir = join(root, "apps", app)
        let configPath = join(appDir, "config.json")
        guard fm.fileExists(atPath: configPath) else {
            throw AppshotError("no such app '\(app)' (\(configPath) missing)")
        }
        let config = try loadJSON(AppConfig.self, at: configPath, what: "config")
        let width = config.output.width, height = config.output.height
        let theme = TemplateEngine.themeDefaults.merging(config.theme ?? [:]) { _, override in override }

        let outputDir = join(root, "output", app)
        try fm.ensureDirectory(outputDir)
        let backgroundURL = try BackgroundRenderer.make(config.background, width: width, height: height,
                                                        scratchPath: join(outputDir, ".bg.bmp"),
                                                        appDir: appDir)

        let deviceDir = join(root, "devices", config.device)
        let devicePath = join(deviceDir, "device.json")
        guard fm.fileExists(atPath: devicePath) else {
            throw AppshotError("device pack '\(config.device)' not found — run: appshot devices fetch \"<device name>\"")
        }
        let device = try loadJSON(DeviceSpec.self, at: devicePath, what: "device pack")
        let (frameW, frameH) = (device.frameSize[0], device.frameSize[1])
        let color = config.deviceColor ?? device.default ?? device.colors.keys.sorted()[0]
        guard let frameFile = device.colors[color] else {
            throw AppshotError("deviceColor '\(color)' not in \(device.colors.keys.sorted())")
        }
        // Slots may override the app-wide device size/position (e.g. a tilted
        // shot rendered smaller so its rotated corners stay inside the canvas).
        // Negative deviceTop/deviceLeft crop the device at the top/left edge;
        // large values crop at the bottom/right.
        func deviceGeometry(deviceWidth: Int, explicitTop: Int?, explicitLeft: Int?) -> [String: String] {
            let scaleFactor = Double(deviceWidth) / Double(frameW)
            func scaled(_ value: Int) -> Int { Int((Double(value) * scaleFactor).rounded()) }
            let deviceHeight = scaled(frameH)
            let deviceTop = explicitTop ?? height - Int((Double(deviceHeight) * 0.82).rounded())
            let deviceLeft = explicitLeft ?? Int((Double(width - deviceWidth) / 2).rounded())
            return [
                "DEV_W": String(deviceWidth), "DEV_H": String(deviceHeight),
                "DEV_TOP": String(deviceTop), "DEV_LEFT": String(deviceLeft),
                "SX": String(scaled(device.screen[0])), "SY": String(scaled(device.screen[1])),
                "SW": String(scaled(device.screen[2])), "SH": String(scaled(device.screen[3])),
            ]
        }

        var baseReplacements: [String: String] = [
            "W": String(width), "H": String(height),
            "BG_IMG": backgroundURL,
            "FRAME": "file://" + join(deviceDir, frameFile),
            "MASK": "file://" + join(deviceDir, device.mask),
            "FONT_FACES": TemplateEngine.fontFaces(config.fonts, appDir: appDir),
        ]
        for (key, value) in theme { baseReplacements["THEME.\(key)"] = value }

        let locales = config.locales.filter { onlyLocales.isEmpty || onlyLocales.contains($0) }
        let slots = config.slots.filter { onlySlots.isEmpty || onlySlots.contains($0.name) }
        guard !locales.isEmpty else {
            throw AppshotError("no locale matches \(onlyLocales) (config has \(config.locales))")
        }
        guard !slots.isEmpty else {
            throw AppshotError("no slot matches \(onlySlots) (config has \(config.slots.map(\.name)))")
        }

        let chrome = try Chrome.find(chromeOverride)
        var count = 0
        for locale in locales {
            let captions = try loadJSON([String: CaptionEntry].self,
                                        at: join(appDir, "captions", "\(locale).json"),
                                        what: "captions for \(locale)")
            let localeDir = join(outputDir, locale)
            try fm.ensureDirectory(localeDir)
            for slot in slots {
                let templatePath = join(root, "templates", slot.template + ".html")
                guard let template = fm.contents(atPath: templatePath)
                    .flatMap({ String(data: $0, encoding: .utf8) }) else {
                    throw AppshotError("missing template \(templatePath)")
                }
                guard let entry = captions[slot.caption] else {
                    throw AppshotError("captions/\(locale).json has no key '\(slot.caption)'")
                }
                var screenshot = join(appDir, "assets", locale, slot.screenshot)
                if !fm.fileExists(atPath: screenshot) {
                    screenshot = join(appDir, "assets", slot.screenshot)
                }
                guard fm.fileExists(atPath: screenshot) else {
                    throw AppshotError("missing screenshot \(screenshot)")
                }
                var replacements = baseReplacements
                for (key, value) in deviceGeometry(
                    deviceWidth: slot.deviceWidth ?? config.layout?.deviceWidth ?? 940,
                    explicitTop: slot.deviceTop ?? config.layout?.deviceTop,
                    explicitLeft: slot.deviceLeft ?? config.layout?.deviceLeft) {
                    replacements[key] = value
                }
                replacements["TILT"] = formatTilt(slot.tilt ?? 0)
                replacements["SCREEN"] = "file://" + screenshot
                replacements["FONT_STACK"] = TemplateEngine.fontStack(config.fonts, locale: locale)
                for (key, text) in entry.fields {
                    replacements["cap.\(key)"] = TemplateEngine.captionHTML(text)
                }
                var page = TemplateEngine.fill(template, with: replacements)
                page = page.replacing(#/\{\{cap\.[A-Za-z0-9_]+\}\}/#, with: "")
                let unfilled = Set(page.matches(of: #/\{\{[^}]+\}\}/#).map { String($0.0) }).sorted()
                guard unfilled.isEmpty else {
                    throw AppshotError("template '\(slot.template)' has unfilled tokens: \(unfilled)")
                }
                let temp = join(localeDir, ".\(slot.name).html")
                try page.write(toFile: temp, atomically: true, encoding: .utf8)
                try Chrome.screenshot(page: temp, output: join(localeDir, slot.name + ".png"),
                                      width: width, height: height, binary: chrome)
                try fm.removeItem(atPath: temp)
                count += 1
                print("  ✓ \(locale)/\(slot.name).png")
            }
        }
        print("\n\(count) screenshot(s) → \(outputDir)")
    }

    private static func formatTilt(_ tilt: Double) -> String {
        tilt == tilt.rounded() ? String(Int(tilt)) : String(tilt)
    }
}
