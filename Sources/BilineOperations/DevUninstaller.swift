import Foundation

public struct DevUninstaller {
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

    public func uninstall(confirmed: Bool) throws -> String {
        guard confirmed else {
            throw BilineOperationError.confirmationRequiredForAction("uninstall dev")
        }

        terminateDevProcesses()
        unregister(paths.legacyDevInputMethodURLs + [paths.devInputMethodInstallURL])
        unregister(paths.legacyDevSettingsURLs + [paths.devSettingsInstallURL])
        removeIfExists(paths.devInputMethodInstallURL)
        removeIfExists(paths.devSettingsInstallURL)
        refreshLaunchServicesAndTextInputAgents()

        return """
            Removed Biline dev apps.
            preserved=Alibaba credentials, Rime userdb, Biline defaults
            manual_host_gate=required
            """
    }

    private func terminateDevProcesses() {
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineIMEDev"], allowFailure: true)
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineSettingsDev"], allowFailure: true)
    }

    private func unregister(_ urls: [URL]) {
        for url in urls {
            _ = try? runner.run(paths.lsregister.path, ["-u", url.path], allowFailure: true)
        }
    }

    private func removeIfExists(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    private func refreshLaunchServicesAndTextInputAgents() {
        _ = try? runner.run(paths.lsregister.path, ["-gc"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["TextInputMenuAgent"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["imklaunchagent"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["cfprefsd"], allowFailure: true)
    }
}
