import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var appState: AppState
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                    )

                VStack(spacing: 8) {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "bandage.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)
                        .scaleEffect(isTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)

                    Text(isTargeted ? "Drop it here!" : "Drag image here")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("or press ⌘V to paste from clipboard")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        BadgeView(text: "WEBP", color: .orange)
                        BadgeView(text: "AVIF", color: .purple)
                        BadgeView(text: "HEIC", color: .blue)
                        BadgeView(text: "EXIF/GPS", color: .red)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        BadgeView(text: "Clean PNG/JPG", color: .green)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
            .frame(height: 140)
            .onDrop(of: [.fileURL, .image, .data], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            Button(action: {
                appState.processFromClipboard()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                    Text("Paste & Strip (⌘V)")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut("v", modifiers: .command)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Check for file URL
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

        // Check for image data
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

struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
