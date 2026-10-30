import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

public enum MenuTriggerMode: String, CaseIterable, Identifiable, Sendable {
    case hybrid = "Hybrid"
    case click = "Click"
    case hover = "Hover"

    public var id: String { rawValue }
}

@MainActor
final public class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var currentResult: ProcessedImage?
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var toastMessage: String?
    @Published public var isCopied: Bool = false
    @Published public var statusBarPulse: Bool = false
    
    // User preferences
    @AppStorage("autoCopyToClipboard") public var autoCopyToClipboard: Bool = true
    @AppStorage("targetFormat") public var targetFormatRaw: String = TargetFormat.auto.rawValue
    @AppStorage("playSound") public var playSound: Bool = true
    @AppStorage("menuTriggerMode") public var menuTriggerModeRaw: String = MenuTriggerMode.click.rawValue

    public var targetFormat: TargetFormat {
        get { TargetFormat(rawValue: targetFormatRaw) ?? .auto }
        set { targetFormatRaw = newValue.rawValue }
    }

    public var menuTriggerMode: MenuTriggerMode {
        get { MenuTriggerMode(rawValue: menuTriggerModeRaw) ?? .click }
        set { menuTriggerModeRaw = newValue.rawValue }
    }

    // Temporary file URL of the latest stripped image for drag-out
    @Published public var temporaryFileURL: URL?

    private var processingTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var copiedResetTask: Task<Void, Never>?
    private var pulseResetTask: Task<Void, Never>?

    public init() {}

    public func processFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        // 1. Check if pasteboard has local file URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let firstURL = urls.first {
            processFile(at: firstURL)
            return
        }

        // 2. Check direct image data (PNG, JPEG, WebP, HEIC, TIFF)
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.webP.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier),
            .tiff
        ]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type) {
                processData(data, filename: nil)
                return
            }
        }

        // 3. Check if NSImage can be initialized from pasteboard
        if let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation {
            processData(tiff, filename: nil)
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
        if !url.isFileURL {
            downloadAndProcess(url: url)
            return
        }

        processingTask?.cancel()
        isProcessing = true
        errorMessage = nil
        let format = targetFormat

        processingTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                try Task.checkCancellation()
                let result = try ImageProcessor.shared.process(
                    data: data,
                    originalFilename: url.lastPathComponent,
                    targetFormat: format
                )
                try Task.checkCancellation()
                await self?.handleProcessingSuccess(result: result)
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func processData(_ data: Data, filename: String? = nil) {
        processingTask?.cancel()
        isProcessing = true
        errorMessage = nil
        let format = targetFormat

        processingTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try ImageProcessor.shared.process(
                    data: data,
                    originalFilename: filename,
                    targetFormat: format
                )
                try Task.checkCancellation()
                await self?.handleProcessingSuccess(result: result)
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func downloadAndProcess(url: URL) {
        processingTask?.cancel()
        isProcessing = true
        errorMessage = nil
        showToast("Fetching image...")
        let format = targetFormat

        processingTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                let filename = response.suggestedFilename ?? url.lastPathComponent
                let result = try ImageProcessor.shared.process(
                    data: data,
                    originalFilename: filename,
                    targetFormat: format
                )
                try Task.checkCancellation()
                await self?.handleProcessingSuccess(result: result)
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { [weak self] in
                    self?.isProcessing = false
                    self?.errorMessage = "Failed to download image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleProcessingSuccess(result: ProcessedImage) {
        cleanupTemporaryFile()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("striptape", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(result.stats.filename)
        try? result.data.write(to: fileURL, options: .atomic)
        self.temporaryFileURL = fileURL

        self.isProcessing = false
        self.currentResult = result

        triggerStatusBarPulse()
        triggerHaptic(.levelChange)

        if autoCopyToClipboard {
            copyCleanedImageToClipboard(silent: true)
            showToast("Stripped & copied to clipboard")
        } else {
            showToast("Metadata stripped")
        }

        playSystemSound("Pop", volume: 0.5)
    }

    public func copyCleanedImageToClipboard(silent: Bool = false) {
        guard let result = currentResult else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        let imagePasteboardType: NSPasteboard.PasteboardType = result.stats.targetFormat == "PNG"
            ? .png
            : NSPasteboard.PasteboardType(UTType.jpeg.identifier)

        item.setData(result.data, forType: imagePasteboardType)

        if let tempURL = temporaryFileURL {
            item.setString(tempURL.absoluteString, forType: .fileURL)
        }

        pasteboard.writeObjects([item])

        markCopiedState()

        if !silent {
            triggerHaptic(.alignment)
            showToast("Copied to clipboard")
            playSystemSound("Tink", volume: 0.45)
        }
    }

    private func markCopiedState() {
        copiedResetTask?.cancel()
        isCopied = true
        copiedResetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self.isCopied = false
        }
    }

    private func triggerStatusBarPulse() {
        pulseResetTask?.cancel()
        statusBarPulse = true
        pulseResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self.statusBarPulse = false
        }
    }

    public func saveToDownloads() {
        guard let result = currentResult else { return }
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
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
            try result.data.write(to: destination, options: .atomic)
            triggerHaptic(.alignment)
            playSystemSound("Tink", volume: 0.45)
            showToast("Saved to Downloads")
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    public func clear() {
        processingTask?.cancel()
        processingTask = nil
        copiedResetTask?.cancel()
        cleanupTemporaryFile()
        triggerHaptic(.alignment)
        playSystemSound("Blow", volume: 0.35)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isCopied = false
            currentResult = nil
            errorMessage = nil
        }
    }

    private func cleanupTemporaryFile() {
        if let url = temporaryFileURL {
            try? FileManager.default.removeItem(at: url)
            temporaryFileURL = nil
        }
    }

    public func triggerHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard playSound else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }

    private func playSystemSound(_ name: String, volume: Float = 0.5) {
        guard playSound else { return }
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = volume
            sound.play()
        }
    }

    public func showToast(_ message: String) {
        toastTask?.cancel()
        self.toastMessage = message
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}
