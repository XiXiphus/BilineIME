import AppKit

extension BilineSettingsModel {
    func openInputSourceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
        {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(
                URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    func openRimeUserDirectory() {
        try? FileManager.default.createDirectory(
            at: rimeUserDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(rimeUserDirectory)
    }
}
