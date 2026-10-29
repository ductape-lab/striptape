import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var appState: AppState
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Main Drop Target Box
            ZStack {
                // Background card
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isTargeted
                                ? [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.06)]
                                : [Color.primary.opacity(0.04), Color.primary.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isTargeted
                                    ? AnyShapeStyle(Color.accentColor.opacity(0.8))
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color.primary.opacity(0.15), Color.primary.opacity(0.06)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    ),
                                style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [6, 4] : [])
                            )
                    )

                VStack(spacing: 9) {
                    // Central Icon Circle
                    ZStack {
                        Circle()
                            .fill(
                                isTargeted
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.primary.opacity(0.06)
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: isTargeted ? "arrow.down" : "bandage.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isTargeted ? .accentColor : .primary.opacity(0.85))
                            .scaleEffect(isTargeted ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
                    }

                    // Main Text
                    Text(isTargeted ? "Drop image to strip" : "Drag image here")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    // Keyboard Shortcut Hint
                    HStack(spacing: 4) {
                        Text("or press")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        KeyCapView(key: "⌘")
                        KeyCapView(key: "V")

                        Text("to paste")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    // Supported Formats Pills
                    HStack(spacing: 5) {
                        FormatTag("WEBP")
                        FormatTag("AVIF")
                        FormatTag("HEIC")
                        FormatTag("EXIF")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.7))
                        FormatTag("PNG/JPG", isOutput: true)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 14)
            }
            .frame(height: 145)
            .onDrop(of: [.fileURL, .image, .data], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Quick Paste Pill Button
            Button(action: {
                appState.processFromClipboard()
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Paste from Clipboard")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    HStack(spacing: 2) {
                        KeyCapView(key: "⌘")
                        KeyCapView(key: "V")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("v", modifiers: .command)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    Task { @MainActor in
                        appState.processFile(at: url)
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data = data {
                    Task { @MainActor in
                        appState.processData(data, filename: "dragged_image")
                    }
                }
            }
            return true
        }

        return false
    }
}

struct KeyCapView: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(.primary.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
            )
    }
}

struct FormatTag: View {
    let text: String
    var isOutput: Bool = false

    init(_ text: String, isOutput: Bool = false) {
        self.text = text
        self.isOutput = isOutput
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isOutput ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
            )
            .foregroundColor(isOutput ? .green : .secondary)
    }
}
