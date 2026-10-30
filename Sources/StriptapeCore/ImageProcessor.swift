import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

public struct StripStats: Sendable {
    public let originalFormat: String
    public let targetFormat: String
    public let originalByteCount: Int
    public let cleanedByteCount: Int
    public let strippedMetadataCount: Int
    public let hadGPS: Bool
    public let width: Int
    public let height: Int
    public let filename: String

    public var sizeSavingsFormatted: String {
        let diff = originalByteCount - cleanedByteCount
        let percent: Double
        if originalByteCount > 0 {
            percent = (Double(diff) / Double(originalByteCount)) * 100.0
        } else {
            percent = 0
        }
        let originalStr = ByteCountFormatter.string(fromByteCount: Int64(originalByteCount), countStyle: .file)
        let cleanedStr = ByteCountFormatter.string(fromByteCount: Int64(cleanedByteCount), countStyle: .file)
        
        if diff > 0 {
            return "\(originalStr) → \(cleanedStr) (-\(Int(percent))%)"
        } else {
            return "\(originalStr) → \(cleanedStr)"
        }
    }
}

public struct ProcessedImage: Sendable {
    public let data: Data
    public let stats: StripStats
    public let nsImage: NSImage
}

public enum TargetFormat: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case png = "PNG"
    case jpeg = "JPG"

    public var id: String { rawValue }
}

public final class ImageProcessor: Sendable {
    public static let shared = ImageProcessor()

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        return formatter
    }()

    public init() {}

    public func process(data: Data, originalFilename: String? = nil, targetFormat: TargetFormat = .auto, jpegQuality: Double = 0.90) throws -> ProcessedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw NSError(domain: "striptape", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode image data"])
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        // Extract orientation (1 = standard upright)
        let orientation: Int = {
            if let o = properties?[kCGImagePropertyOrientation] as? Int {
                return o
            }
            if let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
               let o = tiff[kCGImagePropertyTIFFOrientation] as? Int {
                return o
            }
            return 1
        }()

        // Decode image, baking in EXIF orientation transform if rotated/mirrored
        let cgImage: CGImage
        if orientation != 1, let rawImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            let maxDim = max(rawImage.width, rawImage.height)
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDim
            ]
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) ?? rawImage
        } else {
            guard let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "striptape", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to extract image frame"])
            }
            cgImage = decoded
        }

        let originalType = (CGImageSourceGetType(source) as String?) ?? "public.image"
        let originalFormatName = formatName(fromUTType: originalType, filename: originalFilename)
        
        // Count metadata tags accurately
        var metadataCount = orientation != 1 ? 1 : 0
        var hadGPS = false

        if let properties {
            // Check GPS
            if let gpsDict = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any], !gpsDict.isEmpty {
                hadGPS = true
                metadataCount += gpsDict.count
            }

            // Check EXIF
            if let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                // Filter out synthetic width/height
                for (key, _) in exifDict {
                    let k = key as String
                    if k != (kCGImagePropertyExifPixelXDimension as String) &&
                       k != (kCGImagePropertyExifPixelYDimension as String) {
                        metadataCount += 1
                    }
                }
            }

            // Check TIFF metadata (camera make, model, software, artist, etc.)
            if let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                for (key, _) in tiffDict {
                    let k = key as String
                    if k != "ImageWidth" &&
                       k != "ImageLength" &&
                       k != (kCGImagePropertyTIFFOrientation as String) {
                        metadataCount += 1
                    }
                }
            }

            // Check IPTC (copyright, author, captions)
            if let iptcDict = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
                metadataCount += iptcDict.count
            }

            // Check MakerApple / MakerNote
            if let makerApple = properties[kCGImagePropertyMakerAppleDictionary] as? [CFString: Any] {
                metadataCount += makerApple.count
            }

            // Check PNG text comments
            if let pngDict = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any] {
                if let author = pngDict[kCGImagePropertyPNGAuthor] as? String, !author.isEmpty { metadataCount += 1 }
                if let desc = pngDict[kCGImagePropertyPNGDescription] as? String, !desc.isEmpty { metadataCount += 1 }
                if let soft = pngDict[kCGImagePropertyPNGSoftware] as? String, !soft.isEmpty { metadataCount += 1 }
                if let title = pngDict[kCGImagePropertyPNGTitle] as? String, !title.isEmpty { metadataCount += 1 }
            }
        }

        let width = cgImage.width
        let height = cgImage.height
        let hasAlpha = checkHasAlpha(cgImage: cgImage)

        // Decide destination UTType
        let destinationUTType: CFString
        let resolvedTargetExt: String

        switch targetFormat {
        case .png:
            destinationUTType = UTType.png.identifier as CFString
            resolvedTargetExt = "png"
        case .jpeg:
            destinationUTType = UTType.jpeg.identifier as CFString
            resolvedTargetExt = "jpg"
        case .auto:
            if hasAlpha {
                destinationUTType = UTType.png.identifier as CFString
                resolvedTargetExt = "png"
            } else {
                // If it's a huge photo without transparency, JPG saves tons of bandwidth for discord.
                // If it's a webp or small screenshot, PNG is ultra crisp.
                if originalType.contains("jpeg") || originalType.contains("jpg") || (width * height > 1920 * 1080) {
                    destinationUTType = UTType.jpeg.identifier as CFString
                    resolvedTargetExt = "jpg"
                } else {
                    destinationUTType = UTType.png.identifier as CFString
                    resolvedTargetExt = "png"
                }
            }
        }

        // Export stripped image
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outputData as CFMutableData, destinationUTType, 1, nil) else {
            throw NSError(domain: "striptape", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }

        var destinationProperties: [CFString: Any] = [:]
        if (destinationUTType as String) == UTType.jpeg.identifier {
            destinationProperties[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }

        // Strip ALL metadata by providing only compression quality if JPEG, zero metadata dicts
        CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "striptape", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize clean image"])
        }

        let cleanData = outputData as Data
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

        let baseName: String
        if let original = originalFilename, !original.isEmpty {
            baseName = URL(fileURLWithPath: original).deletingPathExtension().lastPathComponent
        } else {
            baseName = "striptape_\(Self.filenameDateFormatter.string(from: Date()))"
        }
        let cleanFilename = "\(baseName).\(resolvedTargetExt)"

        let stats = StripStats(
            originalFormat: originalFormatName,
            targetFormat: resolvedTargetExt.uppercased(),
            originalByteCount: data.count,
            cleanedByteCount: cleanData.count,
            strippedMetadataCount: max(metadataCount, 1), // at least container metadata stripped
            hadGPS: hadGPS,
            width: width,
            height: height,
            filename: cleanFilename
        )

        return ProcessedImage(data: cleanData, stats: stats, nsImage: nsImage)
    }

    private func checkHasAlpha(cgImage: CGImage) -> Bool {
        let alpha = cgImage.alphaInfo
        let hasAlphaChannel = alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast || alpha == .alphaOnly
        guard hasAlphaChannel else { return false }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let data = context.data else {
            return true
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let ptr = data.assumingMemoryBound(to: UInt8.self)
        let totalBytes = bytesPerRow * height
        for idx in stride(from: 3, to: totalBytes, by: 4) {
            if ptr[idx] < 255 {
                return true
            }
        }
        return false
    }

    private func formatName(fromUTType uti: String, filename: String?) -> String {
        let lower = uti.lowercased()
        if lower.contains("webp") { return "WEBP" }
        if lower.contains("avif") { return "AVIF" }
        if lower.contains("heic") || lower.contains("heif") { return "HEIC" }
        if lower.contains("jpeg") || lower.contains("jpg") { return "JPEG" }
        if lower.contains("png") { return "PNG" }
        if lower.contains("tiff") { return "TIFF" }
        if lower.contains("bmp") { return "BMP" }
        if lower.contains("gif") { return "GIF" }

        if let ext = filename?.components(separatedBy: ".").last?.uppercased(), !ext.isEmpty {
            return ext
        }
        return "IMAGE"
    }
}
