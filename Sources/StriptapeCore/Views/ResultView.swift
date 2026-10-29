import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ResultView: View {
    @ObservedObject var appState: AppState
    let result: ProcessedImage

    var body: some View {
        VStack(spacing: 12) {
            // Preview & Drag-Out Thumbnail
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Image(nsImage: result.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(8)
                    .padding(6)
                    // DRAG-OUT: Users can drag this thumbnail directly into Discord, Slack, Finder!
                    .onDrag {
                        if let tempURL = appState.temporaryFileURL {
                            return NSItemProvider(contentsOf: tempURL) ?? NSItemProvider(object: result.nsImage)
                        } else {
                            return NSItemProvider(object: result.nsImage)
                        }
                    }

                // Drag pill hint
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw.fill")
                    Text("Drag out")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.65))
                .cornerRadius(6)
                .padding(10)
            }
            .frame(height: 150)

            // Metadata & Conversion Summary Box
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Text(result.stats.originalFormat)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(result.stats.targetFormat)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .font(.system(size: 11, design: .monospaced))

                    Spacer()

                    Text(result.stats.sizeSavingsFormatted)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack(spacing: 8) {
                    Label("\(result.stats.strippedMetadataCount) tags removed", systemImage: "shield.slash.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)

                    if result.stats.hadGPS {
                        Label("GPS Stripped", systemImage: "location.slash.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }

                    Spacer()

                    Text("\(result.stats.width)×\(result.stats.height)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    appState.copyCleanedImageToClipboard()
                }) {
                    Label("Copy (⌘C)", systemImage: "doc.on.doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut("c", modifiers: .command)

                Button(action: {
                    appState.saveToDownloads()
                }) {
                    Label("Save", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: {
                    appState.clear()
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Clear")
            }
        }
    }
}
