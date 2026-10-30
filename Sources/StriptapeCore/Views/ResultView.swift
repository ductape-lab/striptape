import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ResultView: View {
    @ObservedObject var appState: AppState
    let result: ProcessedImage

    var body: some View {
        VStack(spacing: 9) {
            // Preview & Drag-Out Thumbnail
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )

                Image(nsImage: result.nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 126)
                    .cornerRadius(4)
                    .padding(6)
                    // DRAG-OUT: Users can drag this thumbnail directly into Discord, Slack, Finder
                    .onDrag {
                        appState.triggerHaptic(.alignment)
                        if let tempURL = appState.temporaryFileURL {
                            return NSItemProvider(contentsOf: tempURL) ?? NSItemProvider(object: result.nsImage)
                        } else {
                            return NSItemProvider(object: result.nsImage)
                        }
                    }

                // Drag Hint Pill
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text("Drag to app")
                        .font(.system(size: 9.5, weight: .medium))
                }
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                )
                .padding(6)
                .allowsHitTesting(false)
            }
            .frame(height: 134)

            // Metrics & Stats Card
            VStack(spacing: 5) {
                // Formats and Size Row
                HStack {
                    HStack(spacing: 4) {
                        Text(result.stats.originalFormat)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))

                        Text(result.stats.targetFormat)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                    Spacer()

                    Text(result.stats.sizeSavingsFormatted)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.85))
                }

                // Stripped Tags & Dimensions Row
                HStack(spacing: 7) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 9))
                        Text("\(result.stats.strippedMetadataCount) tags stripped")
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.green)

                    if result.stats.hadGPS {
                        HStack(spacing: 3) {
                            Image(systemName: "location.slash.fill")
                                .font(.system(size: 8))
                            Text("GPS")
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.orange.opacity(0.12))
                        )
                    }

                    Spacer()

                    Text("\(result.stats.width)×\(result.stats.height)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                    )
            )

            // Action Buttons Row
            HStack(spacing: 7) {
                // Primary Action Button: Morphs between Copy & Copied
                Button(action: {
                    appState.copyCleanedImageToClipboard()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: appState.isCopied ? "checkmark" : "doc.on.doc.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(appState.isCopied ? "Copied" : "Copy Image")
                            .font(.system(size: 11.5, weight: .semibold))

                        if !appState.isCopied {
                            Text("⌘C")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color.white.opacity(0.18))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(appState.isCopied ? Color.green : Color.accentColor)
                    )
                    .foregroundColor(.white)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TactileButtonStyle(cornerRadius: 7))
                .animation(.easeInOut(duration: 0.15), value: appState.isCopied)

                // Save to Downloads
                Button(action: {
                    appState.saveToDownloads()
                }) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(width: 29, height: 29)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5)
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(TactileButtonStyle(cornerRadius: 7))
                .help("Save to Downloads")

                // Reset / Clear
                Button(action: {
                    appState.clear()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(width: 29, height: 29)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5)
                                )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(TactileButtonStyle(cornerRadius: 7))
                .help("Strip another image")
            }
        }
    }
}
