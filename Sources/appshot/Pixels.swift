import Foundation
import PNG

struct RGBAImage {
    var width: Int
    var height: Int
    var pixels: [PNG.RGBA<UInt8>]

    static func decode(path: String) throws -> RGBAImage {
        guard let image = try PNG.Image.decompress(path: path) else {
            throw AppshotError("cannot read PNG at \(path)")
        }
        return RGBAImage(width: image.size.x, height: image.size.y,
                         pixels: image.unpack(as: PNG.RGBA<UInt8>.self))
    }

    func encodeRGBA(path: String) throws {
        let image = PNG.Image(packing: pixels, size: (width, height),
                              layout: .init(format: .rgba8(palette: [], fill: nil)))
        guard try image.compress(path: path, level: 8) != nil else {
            throw AppshotError("cannot write PNG at \(path)")
        }
    }
}
