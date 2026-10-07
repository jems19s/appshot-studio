import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 8-bit RGBA, rows top to bottom, color premultiplied by alpha — the layout CoreGraphics draws into.
struct RGBAImage {
    var width: Int
    var height: Int
    var rgbaBytes: [UInt8]

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    func alpha(atPixel index: Int) -> UInt8 {
        rgbaBytes[index * 4 + 3]
    }

    static func decode(path: String) throws -> RGBAImage {
        let fileURL = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(fileURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AppshotError("cannot read PNG at \(path)")
        }
        let width = image.width, height = image.height
        var rgbaBytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgbaBytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                                          bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw AppshotError("cannot read PNG at \(path)") }
        return RGBAImage(width: width, height: height, rgbaBytes: rgbaBytes)
    }

    func encodeRGBA(path: String) throws {
        let fileURL = URL(fileURLWithPath: path) as CFURL
        guard let provider = CGDataProvider(data: Data(rgbaBytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: Self.colorSpace,
                                  bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo), provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(fileURL, UTType.png.identifier as CFString,
                                                                1, nil) else {
            throw AppshotError("cannot write PNG at \(path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw AppshotError("cannot write PNG at \(path)") }
    }
}
