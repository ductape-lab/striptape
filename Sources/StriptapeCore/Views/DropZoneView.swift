import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var appState: AppState
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            // Main Drop Target Box
            ZStack {
                // Background Surface
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isTargeted
                            ? Color.accentColor.opacity(0.12)
                            : Color.primary.opacity(0.035)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isTargeted
                                    ? Color.accentColor.opacity(0.85)
                                    : Color.primary.opacity(0.1),
                                style: StrokeStyle(
                                    lineWidth: isTargeted ? 1.5 : 0.75,
                                    dash: isTargeted ? [6, 4] : []
                                )
                            )
                    )

                VStack(spacing: 8) {
                    // Central Icon Badge
                    ZStack {
                        Circle()
                            .fill(
                                isTargeted
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.primary.opacity(0.055)
                            )
                            .frame(width: 38, height: 38)

                        Image(systemName: isTargeted ? "arrow.down.doc.fill" : "photo.badge.checkmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isTargeted ? .accentColor : .primary.opacity(0.78))
                    }

                    // Main Prompt
                    Text(isTargeted ? "Release to strip metadata" : "Drop Image Here")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(isTargeted ? .accentColor : .primary)

                    // Keyboard Shortcut Hint
                    HStack(spacing: 4) {
                        Text("or press")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)

                        KeyCapView(key: "⌘V")

                        Text("to paste from clipboard")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }

                    // Supported Formats Pills
                    HStack(spacing: 4) {
                        FormatTag("WEBP")
                        FormatTag("AVIF")
                        FormatTag("HEIC")
                        FormatTag("EXIF")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                        FormatTag("PNG / JPG", isOutput: true)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
            }
            .frame(height: 156)
            .animation(.easeOut(duration: 0.15), value: isTargeted)
            .onChange(of: isTargeted) { targeted in
                if targeted {
                    appState.triggerHaptic(.alignment)
                }
            }
            .onDrop(of: [.fileURL, .image, .url, .data], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Quick Paste Button
            Button(action: {
                appState.processFromClipboard()
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Paste from Clipboard")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.primary.opacity(0.9))
                    Spacer()
                    KeyCapView(key: "⌘V")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7.5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5)
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(TactileButtonStyle(cornerRadius: 7))
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
            let suggestedName = provider.suggestedName
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data = data {
                    Task { @MainActor in
                        appState.processData(data, filename: suggestedName)
                    }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    Task { @MainActor in
                        appState.processFile(at: url)
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
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
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
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(isOutput ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
            )
            .foregroundColor(isOutput ? .accentColor : .secondary)
    }
}
