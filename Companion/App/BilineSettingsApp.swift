import SwiftUI

@main
struct BilineSettingsApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsRootView()
                .frame(minWidth: 860, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
