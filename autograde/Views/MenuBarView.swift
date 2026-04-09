import SwiftUI

struct MenuBarView: View {
    @ObservedObject var vm: AutoGradeViewModel
    @EnvironmentObject var screenshotManager: ScreenshotManager

    var body: some View {
        Group {
            Button("Screenshot  ⌘⇧G") {
                Task { @MainActor in
                    await screenshotManager.capture(
                        settings: vm.screenshotSettings,
                        outputFolder: vm.outputFolder
                    )
                }
            }

            Divider()

            if let msg = screenshotManager.statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Output folder
            Button(vm.outputFolder.map { "→ \($0.lastPathComponent)" } ?? "Set Output Folder…") {
                if let folder = ExportManager.chooseOutputFolder() {
                    vm.outputFolder = folder
                }
            }

            Divider()

            // Watermark toggle
            Toggle("Watermark on screenshots", isOn: $vm.screenshotSettings.watermark)

            if vm.screenshotSettings.watermark {
                TextField("Tag", text: $vm.screenshotSettings.watermarkText)
                    .frame(width: 180)
            }

            Divider()

            Button("Show Window") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows { window.makeKeyAndOrderFront(nil) }
            }

            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
