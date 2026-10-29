import SwiftUI

public struct PopoverView: View {
    @ObservedObject public var appState: AppState
    @State private var showSettings: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("🩹")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("striptape")
                            .font(.system(size: 14, weight: .bold))
                        Text("clean bloat • ready for discord")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSettings.toggle()
                    }
                }) {
                    Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(showSettings ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit striptape")
            }
            .padding(.bottom, 2)

            // Settings Tray (collapsible)
            if showSettings {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Format:")
                            .font(.system(size: 11, weight: .medium))
                        Picker("", selection: $appState.targetFormatRaw) {
                            ForEach(TargetFormat.allCases) { format in
                                Text(format.rawValue).tag(format.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle("Auto-copy to clipboard on drop", isOn: $appState.autoCopyToClipboard)
                        .font(.system(size: 11))

                    Toggle("Open menu on hover", isOn: $appState.openOnHover)
                        .font(.system(size: 11))

                    Toggle("Sound effects", isOn: $appState.playSound)
                        .font(.system(size: 11))
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Main Content: DropZone or Result
            if appState.isProcessing {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Stripping metadata & converting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 140)
            } else if let result = appState.currentResult {
                ResultView(appState: appState, result: result)
            } else {
                DropZoneView(appState: appState)
            }

            // Toast Message Notification Banner
            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.95))
                    .cornerRadius(6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: appState.toastMessage)
            }

            // Error Message Banner
            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .padding(6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
}

// macOS Frosted Glass Background
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
