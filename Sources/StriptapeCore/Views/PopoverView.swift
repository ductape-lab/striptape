import SwiftUI
import AppKit

public struct PopoverView: View {
    @ObservedObject public var appState: AppState
    @State private var showSettings: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Header Bar
            HStack(alignment: .center, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                        )
                        .frame(width: 26, height: 26)

                    Image(systemName: "bandage.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 0.5) {
                    Text("striptape")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(showSettings ? "Preferences" : "Metadata & Format Cleaner")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.15), value: showSettings)
                }

                Spacer()

                // Preferences Toggle Button with Fluid Spring Rotation
                Button(action: {
                    appState.triggerHaptic(.alignment)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showSettings.toggle()
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(showSettings ? .accentColor : .secondary)
                        .rotationEffect(.degrees(showSettings ? 90 : 0))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(showSettings ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(TactileButtonStyle())
                .help(showSettings ? "Back to cleaner" : "Preferences")
            }
            .padding(.horizontal, 1)

            // Content Area (Fixed 204pt Height Slot with Native Push Transition)
            ZStack {
                if showSettings {
                    SettingsCardView(appState: appState, showSettings: $showSettings)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    Group {
                        if appState.isProcessing {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.regular)
                                Text("Stripping metadata...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                                    )
                            )
                        } else if let result = appState.currentResult {
                            ResultView(appState: appState, result: result)
                        } else {
                            DropZoneView(appState: appState)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .frame(height: 204)
            .clipped()
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showSettings)
            .animation(.spring(response: 0.26, dampingFraction: 0.82), value: appState.isProcessing)
            .animation(.spring(response: 0.26, dampingFraction: 0.82), value: appState.currentResult != nil)
        }
        .padding(12)
        .frame(width: 314, height: 260)
        .overlay(alignment: .bottom) {
            if let toast = appState.toastMessage {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                )
                .padding(.bottom, 10)
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
    }
}

private struct SettingsCardView: View {
    @ObservedObject var appState: AppState
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Output Format
            HStack {
                Text("Output Format")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                Spacer()
                Picker("", selection: $appState.targetFormatRaw) {
                    ForEach(TargetFormat.allCases) { format in
                        Text(format.rawValue).tag(format.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 155)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider().opacity(0.35)

            // Menu Bar Trigger Mode (Hybrid, Click, Hover)
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 14)
                    Text("Trigger Mode")
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.88))
                }
                Spacer()
                Picker("", selection: $appState.menuTriggerModeRaw) {
                    ForEach(MenuTriggerMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 155)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider().opacity(0.35)

            // Auto-Copy
            SettingsToggleRow(
                title: "Auto-copy to clipboard",
                icon: "doc.on.clipboard",
                isOn: $appState.autoCopyToClipboard
            )

            Divider().opacity(0.35)

            // Sound & Haptics
            SettingsToggleRow(
                title: "Sound & trackpad haptics",
                icon: "speaker.wave.2",
                isOn: $appState.playSound
            )

            Divider().opacity(0.35)

            // Bottom Actions: Done & Quit
            HStack(spacing: 8) {
                Button(action: {
                    appState.triggerHaptic(.alignment)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        showSettings = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("Done")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(TactileButtonStyle(cornerRadius: 5))

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Quit striptape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary.opacity(0.85))
                        KeyCapView(key: "⌘Q")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                }
                .buttonStyle(TactileButtonStyle(cornerRadius: 5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.88))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5.5)
    }
}

struct TactileButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
