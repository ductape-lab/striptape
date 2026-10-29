import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var currentResult: ProcessedImage?
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var toastMessage: String?
    
    // User preferences
    @AppStorage("autoCopyToClipboard") public var autoCopyToClipboard: Bool = true
    @AppStorage("targetFormat") public var targetFormatRaw: String = TargetFormat.auto.rawValue
    @AppStorage("playSound") public var playSound: Bool = true
    @AppStorage("openOnHover") public var openOnHover: Bool = true

    public var targetFormat: TargetFormat {
        get { TargetFormat(rawValue: targetFormatRaw) ?? .auto }
        set { targetFormatRaw = newValue.rawValue }
    }

    // Temporary file URL of the latest stripped image for drag-out
    @Published public var temporaryFileURL: URL?

    public init() {}

    public func processFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // 1. Check if pasteboard has file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            processFile(at: firstURL)
            return
        }

        // 2. Check direct image data (PNG, TIFF, JPEG)
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff, .pdf]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type) {
                processData(data, filename: "clipboard_image")
                return
            }
        }

        // 3. Check if NSImage can be initialized from pasteboard
        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            processData(tiff, filename: "clipboard_image")
            return
        }

        // 4. Check for URL string in pasteboard
        if let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: string),
           url.scheme == "http" || url.scheme == "https" {
            let pathExt = url.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "webp", "avif", "heic", "gif"].contains(pathExt) {
                downloadAndProcess(url: url)
                return
            }
        }

        showToast("No image found on clipboard")
    }

    public func processFile(at url: URL) {
        isProcessing = true
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: url)
                let result = try ImageProcessor.shared.process(
                    data: data,
                    originalFilename: url.lastPathComponent,
                    targetFormat: await self.targetFormat
                )

                await self.handleProcessingSuccess(result: result)
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func processData(_ data: Data, filename: String? = nil) {
        isProcessing = true
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                let result = try ImageProcessor.shared.process(
                    data: data,
                    originalFilename: filename,
                    targetFormat: await self.targetFormat
                )

                await self.handleProcessingSuccess(result: result)
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func downloadAndProcess(url: URL) {
        isProcessing = true
        errorMessage = nil
        showToast("Fetching image...")

        Task.detached(priority: .userInitiated) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let filename = response.suggestedFilename ?? url.lastPathComponent
                let result = try ImageProcessor.shared.process(
                    data: data,
                    originalFilename: filename,
                    targetFormat: await self.targetFormat
                )

                await self.handleProcessingSuccess(result: result)
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Failed to download image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleProcessingSuccess(result: ProcessedImage) {
        self.isProcessing = false
        self.currentResult = result

        // Write to temporary directory for drag & drop support
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("striptape", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(result.stats.filename)
        try? result.data.write(to: fileURL)
        self.temporaryFileURL = fileURL

        if autoCopyToClipboard {
            copyCleanedImageToClipboard(silent: true)
            showToast("🩹 Stripped & copied to clipboard!")
        } else {
            showToast("🩹 Metadata stripped!")
        }

        if playSound {
            NSSound(named: "Pop")?.play()
        }
    }

    public func copyCleanedImageToClipboard(silent: Bool = false) {
        guard let result = currentResult else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var items: [NSPasteboardWriting] = []

        // If file exists, add file URL (Discord and macOS apps love this)
        if let tempURL = temporaryFileURL {
            items.append(tempURL as NSURL)
        }

        // Add NSImage
        items.append(result.nsImage)

        pasteboard.writeObjects(items)

        // Also explicitly write PNG data for web pasteboards
        if result.stats.targetFormat == "PNG" {
            pasteboard.setData(result.data, forType: .png)
        }

        if !silent {
            showToast("📋 Copied to clipboard!")
            if playSound {
                NSSound(named: "Tink")?.play()
            }
        }
    }

    public func saveToDownloads() {
        guard let result = currentResult else { return }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var destination = downloads.appendingPathComponent(result.stats.filename)

        // Ensure unique filename if already exists
        var counter = 1
        let base = destination.deletingPathExtension().lastPathComponent
        let ext = destination.pathExtension
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = downloads.appendingPathComponent("\(base)_\(counter).\(ext)")
            counter += 1
        }

        do {
            try result.data.write(to: destination)
            showToast("💾 Saved to Downloads!")
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    public func clear() {
        currentResult = nil
        temporaryFileURL = nil
        errorMessage = nil
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}
