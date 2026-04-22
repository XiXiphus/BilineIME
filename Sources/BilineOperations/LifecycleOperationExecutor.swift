import Darwin
import BilineSettings
import Foundation

struct DevLifecycleRuntime {
    let paths: BilineOperationPaths
    let runner: any CommandRunning
    let fileManager: FileManager

    func buildApps() throws {
        try buildInputMethod()
        try buildSettingsApp()
        try requireBuildProduct(paths.devInputMethodBuildURL)
        try requireBuildProduct(paths.devSettingsBuildURL)
    }

    func buildBroker() throws {
        let adHocPrefix = ProcessInfo.processInfo.environment["BILINE_AD_HOC_SIGN"] == "1"
            ? "BILINE_AD_HOC_SIGN=1 "
            : ""
        try runner.runShell(
            """
            cd \(shellQuote(paths.rootDirectory.path))
            \(adHocPrefix)DERIVED_DATA=\(shellQuote(paths.derivedData.path)) CONFIGURATION=Debug make build-broker
            """,
            allowFailure: false
        )
        try requireBuildProduct(paths.devBrokerBuildURL)
    }

    func terminateDevProcesses() {
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineIMEDev"], allowFailure: true)
        _ = try? runner.run("/usr/bin/pkill", ["-x", "BilineSettingsDev"], allowFailure: true)
        _ = try? runner.run("/bin/sleep", ["1"], allowFailure: true)
    }

    func unregister(_ urls: [URL]) {
        for url in urls {
            _ = try? runner.run(paths.lsregister.path, ["-u", url.path], allowFailure: true)
        }
    }

    func installBundles(_ pairs: [LifecycleBundleInstallPair]) throws {
        for pair in pairs {
            try fileManager.createDirectory(
                at: pair.destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            remove([pair.destination], useSudo: false)
            try runner.run("/usr/bin/ditto", [pair.source.path, pair.destination.path], allowFailure: false)
            try runner.run("/bin/chmod", ["-R", "u+w", pair.destination.path], allowFailure: true)
            try runner.run("/usr/bin/xattr", ["-cr", pair.destination.path], allowFailure: true)
        }
    }

    func installBroker(_ installs: [LifecycleBrokerInstall]) throws {
        for install in installs {
            try fileManager.createDirectory(
                at: install.executableDestination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try runner.run("/usr/bin/ditto", [install.executableSource.path, install.executableDestination.path], allowFailure: false)
            try runner.run("/bin/chmod", ["755", install.executableDestination.path], allowFailure: true)
            try writeLaunchAgentPlist(
                at: install.launchAgentDestination,
                executable: install.executableDestination,
                label: install.launchAgentLabel
            )
            try bootstrapLaunchAgent(
                plistURL: install.launchAgentDestination,
                label: install.launchAgentLabel,
                scope: install.scope
            )
        }
    }

    func remove(_ urls: [URL], useSudo: Bool) {
        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            if useSudo || geteuid() == 0 {
                _ = try? runner.run("/bin/rm", ["-rf", url.path], allowFailure: true)
            } else {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func removeBroker(_ installs: [LifecycleBrokerInstall]) {
        for install in installs {
            unloadLaunchAgent(label: install.launchAgentLabel, scope: install.scope)
            remove([install.launchAgentDestination], useSudo: install.scope.requiresRootPrivileges)
            remove([install.executableDestination], useSudo: install.scope.requiresRootPrivileges)
        }
    }

    func purgeData(_ urls: [URL]) {
        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    func register(_ urls: [URL]) {
        for url in urls {
            _ = try? runner.run(paths.lsregister.path, ["-f", "-R", "-trusted", url.path], allowFailure: true)
        }
    }

    func pruneHitoolbox() {
        BilineHitoolboxStatePruner(runner: runner, fileManager: fileManager).pruneBilineSources()
    }

    func clearIntlDataCache() throws {
        try runner.runShell("rm -f /System/Library/Caches/com.apple.IntlDataCache*", allowFailure: true)
        try runner.runShell("rm -f /var/folders/*/*/*/com.apple.IntlDataCache*", allowFailure: true)
    }

    func resetLaunchServices() throws {
        try runner.run(paths.lsregister.path, ["-delete"], allowFailure: false)
    }

    func refreshAgents() {
        _ = try? runner.run(paths.lsregister.path, ["-gc"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["TextInputMenuAgent"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["imklaunchagent"], allowFailure: true)
        _ = try? runner.run("/usr/bin/killall", ["cfprefsd"], allowFailure: true)
    }

    func forgetPackageReceipt(_ identifier: String) {
        _ = try? runner.run("/usr/sbin/pkgutil", ["--forget", identifier], allowFailure: true)
    }

    func resetSharedConfiguration(_ inputMethodBundleIdentifier: String) {
        BilineSharedConfigurationStore(
            inputMethodBundleIdentifier: inputMethodBundleIdentifier
        ).resetToDefaults()
    }

    func clearCredentials(_ inputMethodBundleIdentifier: String) {
        BilineCredentialVault(inputMethodBundleIdentifier: inputMethodBundleIdentifier).clear()
    }

    private func buildInputMethod() throws {
        try runner.run(
            paths.rootDirectory.appendingPathComponent("scripts/build-ime-dev.sh").path,
            [],
            allowFailure: false
        )
    }

    private func buildSettingsApp() throws {
        let adHocPrefix = ProcessInfo.processInfo.environment["BILINE_AD_HOC_SIGN"] == "1"
            ? "BILINE_AD_HOC_SIGN=1 "
            : ""
        try runner.runShell(
            """
            cd \(shellQuote(paths.rootDirectory.path))
            \(adHocPrefix)DERIVED_DATA=\(shellQuote(paths.derivedData.path)) CONFIGURATION=Debug make build-settings
            """,
            allowFailure: false
        )
    }

    private func requireBuildProduct(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw BilineOperationError.missingBuildProduct(url)
        }
    }

    private func writeLaunchAgentPlist(
        at url: URL,
        executable: URL,
        label: String
    ) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable.path],
            "RunAtLoad": true,
            "KeepAlive": true,
            "MachServices": [label: true],
            "StandardOutPath": executable.deletingLastPathComponent()
                .appendingPathComponent("broker.out.log").path,
            "StandardErrorPath": executable.deletingLastPathComponent()
                .appendingPathComponent("broker.err.log").path,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: [.atomic])
    }

    private func bootstrapLaunchAgent(
        plistURL: URL,
        label: String,
        scope: LifecycleScope
    ) throws {
        guard let uid = launchAgentUserID(for: scope) else { return }
        _ = try? runner.run(
            "/bin/launchctl",
            ["bootout", "gui/\(uid)/\(label)"],
            allowFailure: true
        )
        _ = try? runner.run(
            "/bin/launchctl",
            ["bootstrap", "gui/\(uid)", plistURL.path],
            allowFailure: true
        )
        _ = try? runner.run(
            "/bin/launchctl",
            ["kickstart", "-k", "gui/\(uid)/\(label)"],
            allowFailure: true
        )
    }

    private func unloadLaunchAgent(label: String, scope: LifecycleScope) {
        guard let uid = launchAgentUserID(for: scope) else { return }
        _ = try? runner.run(
            "/bin/launchctl",
            ["bootout", "gui/\(uid)/\(label)"],
            allowFailure: true
        )
    }

    private func launchAgentUserID(for scope: LifecycleScope) -> String? {
        switch scope {
        case .user:
            return String(getuid())
        case .system, .all:
            let result = try? runner.run(
                "/usr/bin/stat",
                ["-f%u", "/dev/console"],
                allowFailure: true
            )
            return result?.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

public struct LifecycleOperationExecutor {
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

    public func apply(_ spec: LifecycleOperationSpec, confirmed: Bool) throws -> String {
        guard confirmed else {
            throw BilineOperationError.confirmationRequiredForAction(spec.commandLine())
        }
        if spec.requiresRootPrivileges && geteuid() != 0 {
            throw BilineOperationError.privilegedActionRequiresRoot(spec.commandLine())
        }

        let plan = LifecycleOperationPlanner(paths: paths).plan(spec)
        let runtime = DevLifecycleRuntime(paths: paths, runner: runner, fileManager: fileManager)

        for step in plan.steps {
            switch step.action {
            case .buildApps:
                try runtime.buildApps()
            case .buildBroker:
                try runtime.buildBroker()
            case .terminateProcesses:
                runtime.terminateDevProcesses()
            case .unregister(let urls):
                runtime.unregister(urls)
            case .remove(let urls, let useSudo):
                runtime.remove(urls, useSudo: useSudo)
            case .purgeData(let urls):
                runtime.purgeData(urls)
            case .purgeSharedConfiguration(let inputMethodBundleIdentifier):
                runtime.resetSharedConfiguration(inputMethodBundleIdentifier)
            case .clearCredentials(let inputMethodBundleIdentifier):
                runtime.clearCredentials(inputMethodBundleIdentifier)
            case .installBundles(let pairs):
                try runtime.installBundles(pairs)
            case .installBroker(let installs):
                try runtime.installBroker(installs)
            case .removeBroker(let installs):
                runtime.removeBroker(installs)
            case .register(let urls):
                runtime.register(urls)
            case .pruneHitoolbox:
                runtime.pruneHitoolbox()
            case .clearIntlDataCache:
                try runtime.clearIntlDataCache()
            case .resetLaunchServices:
                try runtime.resetLaunchServices()
            case .refreshAgents:
                runtime.refreshAgents()
            case .forgetPackageReceipt(let identifier):
                runtime.forgetPackageReceipt(identifier)
            case .noteOnly:
                continue
            }
        }

        return resultMessage(for: spec)
    }

    private func resultMessage(for spec: LifecycleOperationSpec) -> String {
        switch spec.intent {
        case .install:
            return """
                Installed Biline dev apps.
                manual_host_gate=required
                next=Ask the user to manually select BilineIME Dev, focus TextEdit, type, browse, and commit.
                """
        case .remove:
            if spec.dataPolicy == .purge {
                return """
                    Removed Biline dev apps and local Biline data.
                    relogin_recommended=true
                    ready_for_release_install=true
                    manual_host_gate=required
                    """
            }
            return """
                Removed Biline dev apps.
                preserved=Alibaba credentials, Rime userdb, Biline defaults
                manual_host_gate=required
                """
        case .reset:
            return """
                Completed Biline dev reset depth \(spec.resetDepth.rawValue).
                reboot_required=\(spec.requiresReboot ? "true" : "false")
                reinstall_after_reboot=\(LifecycleOperationSpec.install(scope: .user).commandLine(includeConfirm: true))
                preserved=Alibaba credentials, Rime userdb, Biline defaults
                """
        case .prepareRelease:
            return """
                Prepared Biline dev environment for a release-style install.
                relogin_recommended=true
                ready_for_release_install=true
                manual_host_gate=required
                """
        }
    }
}
