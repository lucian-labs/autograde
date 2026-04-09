import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    @Published var needsRelaunch = false

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
        // Screen recording requires relaunch — poll and flip needsRelaunch when granted
        Task {
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if CGPreflightScreenCaptureAccess() {
                    screenRecordingGranted = true
                    needsRelaunch = true
                    return
                }
            }
        }
    }

    func relaunch() {
        let url = Bundle.main.bundleURL
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = [url.path]
        try? proc.run()
        NSApp.terminate(nil)
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
