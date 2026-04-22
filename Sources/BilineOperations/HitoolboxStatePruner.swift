import BilineSettings
import Foundation

struct BilineHitoolboxStatePruner {
    let runner: any CommandRunning
    let fileManager: FileManager

    init(
        runner: any CommandRunning = ProcessCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.runner = runner
        self.fileManager = fileManager
    }

    func pruneBilineSources() {
        let temporaryURL = fileManager.temporaryDirectory.appendingPathComponent(
            "biline-hitoolbox-\(UUID().uuidString).plist",
            isDirectory: false
        )
        defer { try? fileManager.removeItem(at: temporaryURL) }

        _ = try? runner.run(
            "/usr/bin/defaults",
            ["export", "com.apple.HIToolbox", temporaryURL.path],
            allowFailure: true
        )

        guard fileManager.fileExists(atPath: temporaryURL.path) else { return }
        guard
            let data = try? Data(contentsOf: temporaryURL),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [.mutableContainersAndLeaves],
                format: nil
            ) as? NSMutableDictionary
        else {
            return
        }

        let keys = [
            "AppleEnabledInputSources",
            "AppleSelectedInputSources",
            "AppleInputSourceHistory",
        ]

        var changed = false
        for key in keys {
            guard let entries = plist[key] as? [Any] else { continue }
            let filtered = entries.filter { !shouldRemove($0) }
            if filtered.count != entries.count {
                plist[key] = filtered
                changed = true
            }
        }

        guard changed else { return }

        guard
            let updated = try? PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
        else {
            return
        }

        try? updated.write(to: temporaryURL, options: [.atomic])
        _ = try? runner.run(
            "/usr/bin/defaults",
            ["import", "com.apple.HIToolbox", temporaryURL.path],
            allowFailure: true
        )
        _ = try? runner.run("/usr/bin/killall", ["cfprefsd"], allowFailure: true)
    }

    private func shouldRemove(_ entry: Any) -> Bool {
        guard let dictionary = entry as? NSDictionary else { return false }
        let bundleID = (dictionary["Bundle ID"] as? String) ?? ""
        let inputMode = (dictionary["Input Mode"] as? String) ?? ""

        let bundleIDs = Set([
            BilineAppIdentifier.devInputMethodBundle,
            BilineAppIdentifier.releaseInputMethodBundle,
        ])
        let inputModes = Set([
            BilineAppIdentifier.devInputSource,
            BilineAppIdentifier.releaseInputSource,
        ])

        if bundleIDs.contains(bundleID) || inputModes.contains(inputMode) {
            return true
        }

        return bundleID.contains("io.github.xixiphus.inputmethod.BilineIME")
            || inputMode.contains("io.github.xixiphus.inputmethod.BilineIME")
    }
}
