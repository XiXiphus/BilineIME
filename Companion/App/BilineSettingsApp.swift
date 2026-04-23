import AppKit
import SwiftUI

@main
struct BilineSettingsApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsRootView()
                .frame(minWidth: 860, minHeight: 560)
                .onOpenURL { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .handlesExternalEvents(matching: ["open"])
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
