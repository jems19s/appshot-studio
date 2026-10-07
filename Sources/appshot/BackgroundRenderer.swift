import Foundation

/// Generates the background as a raw BMP — a scratch file Chrome reads once.
enum BackgroundRenderer {
    static func make(_ background: AppConfig.Background, width: Int, height: Int,
                     scratchPath: String, appDir: String) throws -> String {
        switch background.type ?? "mesh" {
        case "image":
            guard let file = background.file else {
                throw AppshotError("background type \"image\" needs a \"file\"")
            }
            return "file://" + join(appDir, "assets", file)
        case "solid":
            guard let color = background.color else {
                throw AppshotError("background type \"solid\" needs a \"color\"")
            }
            let (r, g, b) = try rgb(color)
            var row = [UInt8]()
            row.reserveCapacity(width * 3)
            for _ in 0..<width { row.append(contentsOf: [UInt8(b), UInt8(g), UInt8(r)]) }
            try writeBMP(width: width, height: height,
                         topDownBGR: [[UInt8]](repeating: row, count: height).flatMap { $0 },
                         to: scratchPath)
        case "linear":
            guard let stops = background.stops, !stops.isEmpty else {
                throw AppshotError("background type \"linear\" needs \"stops\"")
            }
            try writeBMP(width: width, height: height,
                         topDownBGR: linear(stops: stops, angle: background.angle ?? 90,
                                            width: width, height: height),
                         to: scratchPath)
        case "mesh":
            guard let colors = background.colors, colors.count == 9 else {
                throw AppshotError("background type \"mesh\" needs exactly 9 \"colors\"")
            }
            try writeBMP(width: width, height: height,
                         topDownBGR: mesh(colors: try colors.map(rgb), width: width, height: height,
                                          scale: background.scale ?? 1.1, blur: background.blur ?? 2.0),
                         to: scratchPath)
        case let unknown:
            throw AppshotError("unknown background type \"\(unknown)\" (mesh | solid | linear | image)")
        }
        return "file://" + scratchPath
    }

    static func rgb(_ hex: String) throws -> (Double, Double, Double) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            throw AppshotError("bad color \"\(hex)\" — expected #rrggbb")
        }
        return (Double((value >> 16) & 0xff), Double((value >> 8) & 0xff), Double(value & 0xff))
    }

    /// 3x3 bilinear mesh gradient: 9 colors at grid points, interpolated, scaled, softened.
    static func mesh(colors grid: [(Double, Double, Double)], width: Int, height: Int,
                     scale: Double, blur: Double) -> [UInt8] {
        let scaledW = Int(Double(width) * scale)
        let scaledH = Int(Double(height) * scale)
        let cropX = (scaledW - width) / 2
        let cropY = (scaledH - height) / 2

        var channels = [Float](repeating: 0, count: width * height * 3)
        channels.withUnsafeMutableBufferPointer { target in
            DispatchQueue.concurrentPerform(iterations: height) { y in
                let v = min(max((Double(y + cropY) + 0.5) * 3.0 / Double(scaledH) - 0.5, 0), 2)
                let row = Int(v), fy = v - Double(row)
                let rowNext = min(row + 1, 2)
                for x in 0..<width {
                    let u = min(max((Double(x + cropX) + 0.5) * 3.0 / Double(scaledW) - 0.5, 0), 2)
                    let col = Int(u), fx = u - Double(col)
                    let colNext = min(col + 1, 2)
                    let tl = grid[row * 3 + col], tr = grid[row * 3 + colNext]
                    let bl = grid[rowNext * 3 + col], br = grid[rowNext * 3 + colNext]
                    let base = (y * width + x) * 3
                    target[base] = Float(bilerp(tl.0, tr.0, bl.0, br.0, fx, fy))
                    target[base + 1] = Float(bilerp(tl.1, tr.1, bl.1, br.1, fx, fy))
                    target[base + 2] = Float(bilerp(tl.2, tr.2, bl.2, br.2, fx, fy))
                }
            }
        }
        if blur > 0 {
            channels = gaussianBlur(channels, width: width, height: height, sigma: blur)
        }
        return quantizeBGR(channels, width: width, height: height)
    }

    /// Linear gradient through `stops` at `angle` degrees (0 = left->right, 90 = top->bottom).
    static func linear(stops: [String], angle: Double, width: Int, height: Int) throws -> [UInt8] {
        let colors = try stops.map(rgb)
        let radians = angle * .pi / 180
        let dx = cos(radians), dy = sin(radians)
        let span = (Double(width * width + height * height)).squareRoot() + 4
        let cx = Double(width) / 2, cy = Double(height) / 2
        let segments = max(colors.count - 1, 1)

        var channels = [Float](repeating: 0, count: width * height * 3)
        channels.withUnsafeMutableBufferPointer { target in
            DispatchQueue.concurrentPerform(iterations: height) { y in
                for x in 0..<width {
                    let projection = (Double(x) - cx) * dx + (Double(y) - cy) * dy
                    let t = min(max(0.5 + projection / span, 0), 1) * Double(segments)
                    let index = min(Int(t), segments - 1)
                    let fraction = t - Double(index)
                    let a = colors[index], b = colors[min(index + 1, colors.count - 1)]
                    let base = (y * width + x) * 3
                    target[base] = Float(a.0 + (b.0 - a.0) * fraction)
                    target[base + 1] = Float(a.1 + (b.1 - a.1) * fraction)
                    target[base + 2] = Float(a.2 + (b.2 - a.2) * fraction)
                }
            }
        }
        return quantizeBGR(channels, width: width, height: height)
    }

    private static func quantizeBGR(_ channels: [Float], width: Int, height: Int) -> [UInt8] {
        var bgr = [UInt8](repeating: 0, count: width * height * 3)
        bgr.withUnsafeMutableBufferPointer { target in
            channels.withUnsafeBufferPointer { source in
                DispatchQueue.concurrentPerform(iterations: height) { y in
                    var index = y * width * 3
                    while index < (y + 1) * width * 3 {
                        target[index] = clamp(source[index + 2])
                        target[index + 1] = clamp(source[index + 1])
                        target[index + 2] = clamp(source[index])
                        index += 3
                    }
                }
            }
        }
        return bgr
    }

    private static func writeBMP(width: Int, height: Int, topDownBGR: [UInt8], to path: String) throws {
        let rowBytes = width * 3
        let padding = (4 - rowBytes % 4) % 4
        let paddedRow = rowBytes + padding
        let pixelBytes = paddedRow * height
        var data = Data(capacity: 54 + pixelBytes)
        func le16(_ value: Int) {
            data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff))
        }
        func le32(_ value: UInt32) {
            for shift in stride(from: 0, to: 32, by: 8) { data.append(UInt8((value >> shift) & 0xff)) }
        }
        data.append(contentsOf: [0x42, 0x4d])
        le32(UInt32(54 + pixelBytes)); le32(0); le32(54)
        le32(40); le32(UInt32(width)); le32(UInt32(bitPattern: Int32(-height)))  // negative = top-down
        le16(1); le16(24)
        le32(0); le32(UInt32(pixelBytes)); le32(2835); le32(2835); le32(0); le32(0)
        if padding == 0 {
            data.append(contentsOf: topDownBGR)
        } else {
            let pad = [UInt8](repeating: 0, count: padding)
            for y in 0..<height {
                data.append(contentsOf: topDownBGR[(y * rowBytes)..<((y + 1) * rowBytes)])
                data.append(contentsOf: pad)
            }
        }
        try data.write(to: URL(fileURLWithPath: path))
    }

    private static func bilerp(_ tl: Double, _ tr: Double, _ bl: Double, _ br: Double,
                               _ fx: Double, _ fy: Double) -> Double {
        let top = tl + (tr - tl) * fx
        let bottom = bl + (br - bl) * fx
        return top + (bottom - top) * fy
    }

    private static func clamp(_ value: Float) -> UInt8 {
        UInt8(min(max(value.rounded(), 0), 255))
    }

    private static func gaussianBlur(_ channels: [Float], width: Int, height: Int, sigma: Double) -> [Float] {
        let radius = max(1, Int((sigma * 3).rounded(.up)))
        var kernel = [Float](repeating: 0, count: radius * 2 + 1)
        var sum: Float = 0
        for offset in -radius...radius {
            let weight = Float(exp(-Double(offset * offset) / (2 * sigma * sigma)))
            kernel[offset + radius] = weight
            sum += weight
        }
        for index in kernel.indices { kernel[index] /= sum }

        var horizontal = [Float](repeating: 0, count: channels.count)
        channels.withUnsafeBufferPointer { source in
            kernel.withUnsafeBufferPointer { weights in
                horizontal.withUnsafeMutableBufferPointer { target in
                    DispatchQueue.concurrentPerform(iterations: height) { y in
                        for x in 0..<width {
                            var r: Float = 0, g: Float = 0, b: Float = 0
                            for offset in -radius...radius {
                                let sx = min(max(x + offset, 0), width - 1)
                                let weight = weights[offset + radius]
                                let base = (y * width + sx) * 3
                                r += source[base] * weight
                                g += source[base + 1] * weight
                                b += source[base + 2] * weight
                            }
                            let base = (y * width + x) * 3
                            target[base] = r
                            target[base + 1] = g
                            target[base + 2] = b
                        }
                    }
                }
            }
        }
        var vertical = [Float](repeating: 0, count: channels.count)
        horizontal.withUnsafeBufferPointer { source in
            kernel.withUnsafeBufferPointer { weights in
                vertical.withUnsafeMutableBufferPointer { target in
                    DispatchQueue.concurrentPerform(iterations: height) { y in
                        for x in 0..<width {
                            var r: Float = 0, g: Float = 0, b: Float = 0
                            for offset in -radius...radius {
                                let sy = min(max(y + offset, 0), height - 1)
                                let weight = weights[offset + radius]
                                let base = (sy * width + x) * 3
                                r += source[base] * weight
                                g += source[base + 1] * weight
                                b += source[base + 2] * weight
                            }
                            let base = (y * width + x) * 3
                            target[base] = r
                            target[base + 1] = g
                            target[base + 2] = b
                        }
                    }
                }
            }
        }
        return vertical
    }
}
