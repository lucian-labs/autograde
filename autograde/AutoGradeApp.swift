import SwiftUI

@main
struct AutoGradeApp: App {
    @StateObject private var screenshotManager = ScreenshotManager.shared
    @StateObject private var permissions = PermissionsManager.shared
    @StateObject private var vm = AutoGradeViewModel()
    @State private var showPermissions = false

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .frame(minWidth: 860, minHeight: 580)
                .environmentObject(screenshotManager)
                .environmentObject(permissions)
                .sheet(isPresented: $showPermissions) {
                    PermissionsView(manager: permissions) {
                        showPermissions = false
                        screenshotManager.startHotkeyListener { triggerCapture() }
                    }
                }
                .onAppear {
                    permissions.checkAll()
                    if permissions.needsSetup {
                        showPermissions = true
                    } else {
                        screenshotManager.startHotkeyListener { triggerCapture() }
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
