import AppKit
import SwiftUI

@main
struct CaffeineCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Caffeine Cat", id: "main") {
            CaffeinePanel()
                .environment(appDelegate.caffeine)
                // With the window open, the app is in the Dock and in Cmd+Tab.
                // With the window closed, the app stays only in the menu bar.
                .onAppear { NSApp.setActivationPolicy(.regular) }
                .onDisappear { NSApp.setActivationPolicy(.accessory) }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            CaffeinePanel(compact: true)
                .environment(appDelegate.caffeine)
        } label: {
            Image(systemName: appDelegate.caffeine.isAwake ? "cup.and.heat.waves.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let caffeine = CaffeineController()

    /// Closing the window keeps the app alive in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeine.stop()
    }
}
