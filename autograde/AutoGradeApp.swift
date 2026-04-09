import SwiftUI

@main
struct AutoGradeApp: App {
    @StateObject private var screenshotManager = ScreenshotManager.shared
    @StateObject private var vm = AutoGradeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .frame(minWidth: 860, minHeight: 580)
                .environmentObject(screenshotManager)
                .onAppear {
                    screenshotManager.startHotkeyListener {
                        triggerCapture()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Capture") {
                Button("Screenshot  ⌘⇧G") { triggerCapture() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }

        // Menu bar icon — app stays alive and reachable without the main window
        MenuBarExtra("autograde", systemImage: "camera.viewfinder") {
            MenuBarView(vm: vm)
                .environmentObject(screenshotManager)
        }
        .menuBarExtraStyle(.menu)
    }

    private func triggerCapture() {
        Task { @MainActor in
            await screenshotManager.capture(
                settings: vm.screenshotSettings,
                outputFolder: vm.outputFolder
            )
        }
    }
}
