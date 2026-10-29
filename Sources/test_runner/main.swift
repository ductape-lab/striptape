import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import StriptapeCore

print("🩹 Running striptape test suite...\n")

func assertTest(_ condition: Bool, _ message: String) {
    if !condition {
        print("❌ Assertion failed: \(message)")
        exit(1)
    }
}

// TEST 1: Strip GPS & EXIF from bloated image
do {
    print("▶ Test 1: Stripping GPS & EXIF metadata and converting to PNG...")
    let width = 200
    let height = 200
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let cgImage = context.makeImage() else {
        fatalError("Failed to make CGImage")
    }

    // Embed rich metadata (GPS location, camera serial, EXIF)
    let bloatedMetadata: [CFString: Any] = [
        kCGImagePropertyGPSDictionary: [
            kCGImagePropertyGPSLatitude: 40.7128,
            kCGImagePropertyGPSLongitude: -74.0060,
            kCGImagePropertyGPSAltitude: 10.0
        ],
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifLensModel: "DuctTape 35mm f/1.4",
            kCGImagePropertyExifUserComment: "Bloated Mac screenshot metadata",
            kCGImagePropertyExifDateTimeOriginal: "2026:10:30 02:00:00"
        ],
        kCGImagePropertyTIFFDictionary: [
            kCGImagePropertyTIFFMake: "Apple",
            kCGImagePropertyTIFFModel: "MacBookPro"
        ]
    ]

    let initialData = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(initialData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
        fatalError("Failed to create initial destination")
    }

    CGImageDestinationAddImage(dest, cgImage, bloatedMetadata as CFDictionary)
    assertTest(CGImageDestinationFinalize(dest), "Initial image destination finalize failed")

    let rawBloatedData = initialData as Data
    let sourceBefore = CGImageSourceCreateWithData(rawBloatedData as CFData, nil)!
    let propsBefore = CGImageSourceCopyPropertiesAtIndex(sourceBefore, 0, nil) as? [CFString: Any]

    assertTest(propsBefore?[kCGImagePropertyGPSDictionary] != nil, "Original data must contain GPS dictionary")
    assertTest(propsBefore?[kCGImagePropertyExifDictionary] != nil, "Original data must contain EXIF dictionary")
    print("   ✓ Original image created with GPS & EXIF metadata (\(rawBloatedData.count) bytes)")

    // Run stripper
    let result = try ImageProcessor.shared.process(
        data: rawBloatedData,
        originalFilename: "bloated_photo.jpg",
        targetFormat: .png
    )

    // Inspect result
    let sourceAfter = CGImageSourceCreateWithData(result.data as CFData, nil)!
    let propsAfter = CGImageSourceCopyPropertiesAtIndex(sourceAfter, 0, nil) as? [CFString: Any]

    // Verify GPS is completely gone
    assertTest(propsAfter?[kCGImagePropertyGPSDictionary] == nil, "GPS dictionary must be completely stripped")
    
    // Verify custom EXIF / Lens info is completely gone
    if let exifAfter = propsAfter?[kCGImagePropertyExifDictionary] as? [CFString: Any] {
        assertTest(exifAfter[kCGImagePropertyExifLensModel] == nil, "Lens model must be stripped")
        assertTest(exifAfter[kCGImagePropertyExifUserComment] == nil, "User comment must be stripped")
        assertTest(exifAfter[kCGImagePropertyExifDateTimeOriginal] == nil, "Timestamp must be stripped")
    }
    
    // Verify camera make/model is gone
    if let tiffAfter = propsAfter?[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
        assertTest(tiffAfter[kCGImagePropertyTIFFMake] == nil, "Camera make must be stripped")
        assertTest(tiffAfter[kCGImagePropertyTIFFModel] == nil, "Camera model must be stripped")
    }

    assertTest(result.stats.hadGPS == true, "Stats should record that GPS was present")
    assertTest(result.stats.strippedMetadataCount >= 5, "Should record stripped metadata keys")
    assertTest(result.stats.targetFormat == "PNG", "Target format should be PNG")
    assertTest(result.stats.filename == "bloated_photo.png", "Filename should have .png extension")

    print("   ✓ Cleaned image has ZERO GPS, ZERO camera tags, and ZERO personal comments.")
    print("   ✓ Stats: \(result.stats.sizeSavingsFormatted), Stripped \(result.stats.strippedMetadataCount) tags.")
} catch {
    print("❌ Test 1 failed with error: \(error)")
    exit(1)
}

// TEST 2: Transparency preservation in Auto mode
do {
    print("\n▶ Test 2: Auto format selection for transparent images...")
    let width = 50
    let height = 50
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    )!

    context.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.4))
    context.fill(CGRect(x: 0, y: 0, width: 25, height: 50))

    let cgImage = context.makeImage()!
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cgImage, nil)
    CGImageDestinationFinalize(dest)

    let result = try ImageProcessor.shared.process(
        data: data as Data,
        originalFilename: "icon_transparent.png",
        targetFormat: .auto
    )

    assertTest(result.stats.targetFormat == "PNG", "Transparent images in Auto mode must stay PNG")
    print("   ✓ Transparency recognized, formatted as clean PNG.")
} catch {
    print("❌ Test 2 failed: \(error)")
    exit(1)
}

// TEST 3: WebP/AVIF simulated conversion to Discord JPG
do {
    print("\n▶ Test 3: Photo conversion to Discord-friendly JPG...")
    let width = 400
    let height = 400
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    )!

    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1.0))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let cgImage = context.makeImage()!
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cgImage, nil)
    CGImageDestinationFinalize(dest)

    let result = try ImageProcessor.shared.process(
        data: data as Data,
        originalFilename: "downloaded_web_meme.webp",
        targetFormat: .jpeg
    )

    assertTest(result.stats.targetFormat == "JPG", "Format should be JPG")
    assertTest(result.stats.filename == "downloaded_web_meme.jpg", "Extension should be .jpg")
    print("   ✓ Converted WEBP ➔ JPG (\(result.stats.sizeSavingsFormatted)).")
} catch {
    print("❌ Test 3 failed: \(error)")
    exit(1)
}

print("\n✨ All 3 tests passed! striptape is rock solid.\n")
