import SwiftUI

public struct PopoverView: View {
    @ObservedObject public var appState: AppState
    @State private var showSettings: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Header Bar
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Text("🩹")
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("striptape")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                        }

                        Text("metadata bloat cleaner")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    // Settings Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSettings.toggle()
                        }
                    }) {
                        Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(showSettings ? .accentColor : .secondary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(showSettings ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Preferences")

                    // Quit Button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .help("Quit striptape")
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)

            // Settings Tray (collapsible)
            if showSettings {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Output Format")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $appState.targetFormatRaw) {
                            ForEach(TargetFormat.allCases) { format in
                                Text(format.rawValue).tag(format.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }

                    Divider()
                        .opacity(0.5)

                    Toggle(isOn: $appState.autoCopyToClipboard) {
                        Text("Auto-copy to clipboard after strip")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $appState.openOnHover) {
                        Text("Open menu when hovered in taskbar")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $appState.playSound) {
                        Text("Play audio feedback")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Main Content Area
            if appState.isProcessing {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Stripping bloat & converting...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(height: 145)
            } else if let result = appState.currentResult {
                ResultView(appState: appState, result: result)
            } else {
                DropZoneView(appState: appState)
            }

            // Toast Notification Banner
            if let toast = appState.toastMessage {
                HStack(spacing: 5) {
                    Text(toast)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(NSColor.windowBackgroundColor))
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.toastMessage)
            }

            // Error Message
            if let error = appState.errorMessage {
                Text(error)
                    .font(.system(size: 10.5))
                    .foregroundColor(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                    )
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
