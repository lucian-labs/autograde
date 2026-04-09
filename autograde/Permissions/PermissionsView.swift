import SwiftUI

struct PermissionsView: View {
    @ObservedObject var manager: PermissionsManager
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Permissions Required")
                    .font(.system(size: 16, weight: .semibold))
                Text("autograde needs two permissions to run. These are only used for hotkey capture and screen selection.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider().opacity(0.4)

            // Permission rows
            VStack(spacing: 0) {
                PermissionRow(
                    icon: "keyboard",
                    title: "Accessibility",
                    description: "Enables the global ⌘⇧G hotkey from any app.",
                    granted: manager.accessibilityGranted,
                    onGrant: {
                        manager.requestAccessibility()
                    },
                    onOpenSettings: {
                        manager.openAccessibilitySettings()
                    }
                )

                Divider().opacity(0.3).padding(.leading, 52)

                PermissionRow(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Required to capture screen selections.",
                    granted: manager.screenRecordingGranted,
                    onGrant: {
                        manager.requestScreenRecording()
                    },
                    onOpenSettings: {
                        manager.openScreenRecordingSettings()
                    }
                )
            }
            .padding(.vertical, 4)

            Divider().opacity(0.4)

            // Footer
            HStack {
                Button("Skip for now") { onContinue() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button(manager.allGranted ? "Continue" : "Continue anyway") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(false) // always allow continue
            }
            .padding(16)
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { manager.checkAll() }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    var onGrant: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            } else {
                Button("Grant") { onGrant() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .onLongPressGesture { onOpenSettings() }
                    .help("Click to grant — long-press to open System Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
