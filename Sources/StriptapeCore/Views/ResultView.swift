import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ResultView: View {
    @ObservedObject var appState: AppState
    let result: ProcessedImage

    var body: some View {
        VStack(spacing: 10) {
            // Preview & Drag-Out Thumbnail
            ZStack(alignment: .bottomTrailing) {
                // Background Card with crisper corners
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                // Image
                Image(nsImage: result.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 140)
                    .cornerRadius(5)
                    .padding(6)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, y: 2)
                    // DRAG-OUT: Users can drag this thumbnail directly into Discord, Slack, Finder
                    .onDrag {
                        if let tempURL = appState.temporaryFileURL {
                            return NSItemProvider(contentsOf: tempURL) ?? NSItemProvider(object: result.nsImage)
                        } else {
                            return NSItemProvider(object: result.nsImage)
                        }
                    }

                // Drag Hint Badge
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Drag out")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                )
                .padding(8)
            }
            .frame(height: 140)

            // Metrics & Stats Card
            VStack(spacing: 7) {
                // Formats and Size Row
                HStack {
                    HStack(spacing: 4) {
                        Text(result.stats.originalFormat)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))

                        Text(result.stats.targetFormat)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(3)

                    Spacer()

                    Text(result.stats.sizeSavingsFormatted)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.85))
                }

                // Stripped Tags & Dimensions Row
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 9.5))
                        Text("\(result.stats.strippedMetadataCount) tags stripped")
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.green)

                    if result.stats.hadGPS {
                        HStack(spacing: 3) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 8.5))
                            Text("GPS removed")
                        }
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.orange)
                    }

                    Spacer()

                    Text("\(result.stats.width)×\(result.stats.height)")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )

            // Action Buttons Row
            HStack(spacing: 7) {
                // Primary Action Button: Copy
                Button(action: {
                    appState.copyCleanedImageToClipboard()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("Copy Image")
                            .font(.system(size: 11.5, weight: .semibold))
                        KeyCapView(key: "⌘C")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: .command)

                // Save to Downloads
                Button(action: {
                    appState.saveToDownloads()
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12, weight: .medium))
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.primary.opacity(0.09), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("Save to Downloads")

                // Reset / Clear
                Button(action: {
                    appState.clear()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11.5, weight: .medium))
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.primary.opacity(0.09), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("Strip another image")
            }
        }
    }
}
