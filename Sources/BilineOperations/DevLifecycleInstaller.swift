import Foundation

public struct DevLifecycleInstaller {
    public let paths: BilineOperationPaths
    public let runner: any CommandRunning
    private let fileManager: FileManager

    public init(
        paths: BilineOperationPaths = BilineOperationPaths(),
        runner: any CommandRunning = ProcessCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.runner = runner
        self.fileManager = fileManager
    }

    public func reinstall(level: BilineOperationLevel, confirmed: Bool) throws -> String {
        guard confirmed else {
            throw BilineOperationError.confirmationRequired(level)
        }

        switch level {
        case .level1:
            try reinstallLevel1()
            return """
                Reinstalled Biline dev apps.
                manual_host_gate=required
                next=Ask the user to manually select BilineIME Dev, focus TextEdit, type, browse, and commit.
                """
        case .level2:
            try repairLevel2(includeLaunchServicesReset: false)
            return rebootMessage(level: level)
        case .level3:
            try repairLevel2(includeLaunchServicesReset: true)
            return rebootMessage(level: level)
        }
    }

    private func reinstallLevel1() throws {
        try buildInputMethod()
        try buildSettingsApp()
        try requireBuildProduct(paths.devInputMethodBuildURL)
        try requireBuildProduct(paths.devSettingsBuildURL)

        terminateDevProcesses()
        unregister(paths.legacyDevInputMethodURLs + [paths.devInputMethodInstallURL])
        unregister(paths.legacyDevSettingsURLs + [paths.devSettingsInstallURL])

        try replaceBundle(from: paths.devInputMethodBuildURL, to: paths.devInputMethodInstallURL)
        try replaceBundle(from: paths.devSettingsBuildURL, to: paths.devSettingsInstallURL)

        register([paths.devInputMethodInstallURL, paths.devSettingsInstallURL])
        refreshLaunchServicesAndTextInputAgents()
    }

    private func repairLevel2(includeLaunchServicesReset: Bool) throws {
        terminateDevProcesses()
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineIME"], allowFailure: true)

        unregister(
            paths.legacyDevInputMethodURLs
                + paths.legacyDevSettingsURLs
                + paths.legacyReleaseInputMethodURLs
                + [
                    paths.devInputMethodInstallURL, paths.devSettingsInstallURL,
                    paths.releaseInputMethodInstallURL,
                ]
        )

        removeIfExists(paths.devInputMethodInstallURL, useSudo: false)
        removeIfExists(paths.devSettingsInstallURL, useSudo: false)
        removeIfExists(paths.releaseInputMethodInstallURL, useSudo: true)

        _ = try? runner.run(
            paths.rootDirectory.appendingPathComponent("scripts/prune-hitoolbox-sources.sh").path,
            [],
            allowFailure: true
        )
        try runner.runShell(
            "sudo rm -f /System/Library/Caches/com.apple.IntlDataCache*", allowFailure: true)
        try runner.runShell(
            "sudo rm -f /var/folders/*/*/*/com.apple.IntlDataCache*", allowFailure: true)

        if includeLaunchServicesReset {
            try runner.run(
                "/usr/bin/sudo", [paths.lsregister.path, "-delete"], allowFailure: false)
        }

        refreshLaunchServicesAndTextInputAgents()
    }

    private func buildInputMethod() throws {
        try runner.run(
            paths.rootDirectory.appendingPathComponent("scripts/build-ime-dev.sh").path, [],
            allowFailure: false)
    }

    private func buildSettingsApp() throws {
        try runner.runShell(
            """
            cd \(shellQuote(paths.rootDirectory.path))
            xcodegen generate
            /usr/bin/xcodebuild -project BilineIME.xcodeproj -scheme BilineSettingsDev -configuration Debug -derivedDataPath \(shellQuote(paths.derivedData.path)) build
            """,
            allowFailure: false
        )
    }

    private func requireBuildProduct(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw BilineOperationError.missingBuildProduct(url)
        }
    }

    private func terminateDevProcesses() {
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineIMEDev"], allowFailure: true)
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineSettingsDev"], allowFailure: true)
        _ = try? runner.run("/bin/sleep", ["1"], allowFailure: true)
    }

    private func unregister(_ urls: [URL]) {
        for url in urls {
            _ = try? runner.run(paths.lsregister.path, ["-u", url.path], allowFailure: true)
        }
    }

    private func register(_ urls: [URL]) {
        for url in urls {
            _ = try? runner.run(
                paths.lsregister.path, ["-f", "-R", "-trusted", url.path], allowFailure: true)
        }
    }

    private func replaceBundle(from source: URL, to destination: URL) throws {
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        removeIfExists(destination, useSudo: false)
        try runner.run("/usr/bin/ditto", [source.path, destination.path], allowFailure: false)
        try runner.run("/bin/chmod", ["-R", "u+w", destination.path], allowFailure: true)
        try runner.run("/usr/bin/xattr", ["-cr", destination.path], allowFailure: true)
    }

    private func removeIfExists(_ url: URL, useSudo: Bool) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        if useSudo {
            _ = try? runner.run("/usr/bin/sudo", ["/bin/rm", "-rf", url.path], allowFailure: true)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }

    private func refreshLaunchServicesAndTextInputAgents() {
        _ = try? runner.run(paths.lsregister.path, ["-gc"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["TextInputMenuAgent"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["imklaunchagent"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["cfprefsd"], allowFailure: true)
    }

    private func rebootMessage(level: BilineOperationLevel) -> String {
        """
        Completed Biline dev lifecycle repair level \(level.rawValue).
        reboot_required=true
        reinstall_after_reboot=swift run bilinectl reinstall dev --level 1 --confirm
        preserved=Alibaba credentials, Rime userdb, Biline defaults
        """
    }
}
