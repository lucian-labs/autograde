import AppKit
import ApplicationServices

/// Triggers macOS interactive screen selection, applies branding, saves result.
@MainActor
class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()

    @Published var lastCapture: NSImage?
    @Published var statusMessage: String?

    private var hotKeyMonitor: Any?

    // MARK: - Hotkey (⌘⇧G)

    func startHotkeyListener(onTrigger: @escaping () -> Void) {
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            return
        }
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection([.command, .shift, .control, .option]) == [.command, .shift],
                  event.charactersIgnoringModifiers?.lowercased() == "g"
            else { return }
            DispatchQueue.main.async { onTrigger() }
        }
    }

    func stopHotkeyListener() {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
            hotKeyMonitor = nil
        }
    }

    private func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        statusMessage = "Enable Accessibility in System Settings → Privacy to use the global hotkey"
    }

    // MARK: - Capture

    /// Launches macOS interactive screen-select UI, then brands and saves the result.
    func capture(settings: EditSettings, outputFolder: URL?) async {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ag_cap_\(UUID().uuidString).png")

        // Bring screencapture UI forward — hide our window briefly so it doesn't interfere
        NSApp.hide(nil)
        try? await Task.sleep(nanoseconds: 150_000_000)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = [
            "-i",          // interactive selection
            "-x",          // no sound
            "-t", "png",
            tmpURL.path
        ]

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            await show("screencapture failed: \(error.localizedDescription)")
            return
        }

        NSApp.unhide(nil)

        guard let raw = NSImage(contentsOf: tmpURL) else {
            // User cancelled (no file written)
            return
        }
        try? FileManager.default.removeItem(at: tmpURL)

        // Brand
        let branded = await ImageProcessor.shared.process(image: raw, settings: settings) ?? raw
        lastCapture = branded

        // Save
        let dest = outputFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let outURL = dest.appendingPathComponent("screenshot_\(stamp)_ag.jpg")

        do {
            guard let cg = branded.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let dst = CGImageDestinationCreateWithURL(outURL as CFURL, "public.jpeg" as CFString, 1, nil)
            else { throw ExportError.renderFailed }
            CGImageDestinationAddImage(dst, cg, [kCGImageDestinationLossyCompressionQuality: 0.93] as CFDictionary)
            guard CGImageDestinationFinalize(dst) else { throw ExportError.writeFailed }
            await show("Saved → \(outURL.lastPathComponent)")
        } catch {
            await show("Export failed: \(error.localizedDescription)")
        }
    }

    private func show(_ msg: String) async {
        statusMessage = msg
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        statusMessage = nil
    }
}
