import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false

    var allGranted: Bool { accessibilityGranted && screenRecordingGranted }
    var needsSetup: Bool { !allGranted }

    func checkAll() {
        accessibilityGranted  = AXIsProcessTrusted()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        pollUntilGranted(\.accessibilityGranted) { AXIsProcessTrusted() }
    }

    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        pollUntilGranted(\.screenRecordingGranted) { CGPreflightScreenCaptureAccess() }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        )
    }

    // Poll for up to 30s after the user returns from System Settings
    private func pollUntilGranted(
        _ keyPath: ReferenceWritableKeyPath<PermissionsManager, Bool>,
        check: @escaping () -> Bool
    ) {
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if check() {
                    self[keyPath: keyPath] = true
                    return
                }
            }
        }
    }
}
