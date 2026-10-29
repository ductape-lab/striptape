import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var appState: AppState
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            // Main Drop Target Box
            ZStack {
                // Background card with crisper, less round corners
                RoundedRectangle(cornerRadius: 7, style: .continuous)
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
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                isTargeted
                                    ? AnyShapeStyle(Color.accentColor.opacity(0.8))
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color.primary.opacity(0.14), Color.primary.opacity(0.05)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    ),
                                style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: isTargeted ? [5, 3] : [])
                            )
                    )

                VStack(spacing: 8) {
                    // Central Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                isTargeted
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.primary.opacity(0.05)
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: isTargeted ? "arrow.down" : "bandage.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isTargeted ? .accentColor : .primary.opacity(0.8))
                            .scaleEffect(isTargeted ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
                    }

                    // Main Text
                    Text(isTargeted ? "Drop image to strip" : "Drag image here")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.primary)

                    // Keyboard Shortcut Hint
                    HStack(spacing: 4) {
                        Text("or press")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)

                        KeyCapView(key: "⌘")
                        KeyCapView(key: "V")

                        Text("to paste")
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
                            .foregroundColor(.secondary.opacity(0.7))
                        FormatTag("PNG/JPG", isOutput: true)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
            }
            .frame(height: 140)
            .onDrop(of: [.fileURL, .image, .data], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Quick Paste Button with crisp corners
            Button(action: {
                appState.processFromClipboard()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Paste from Clipboard")
                        .font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    HStack(spacing: 2) {
                        KeyCapView(key: "⌘")
                        KeyCapView(key: "V")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
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
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isOutput ? Color.green.opacity(0.12) : Color.primary.opacity(0.05))
            )
            .foregroundColor(isOutput ? .green : .secondary)
    }
}
