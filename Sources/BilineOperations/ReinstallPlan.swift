import BilineSettings
import Foundation

public typealias LifecycleScope = BilineInstallSurfaceSelection

public enum LifecycleIntent: String, CaseIterable, Sendable, Codable {
    case install
    case remove
    case reset
    case prepareRelease
}

public enum LifecycleDataPolicy: String, CaseIterable, Sendable, Codable {
    case preserve
    case purge
}

public enum LifecycleResetDepth: String, CaseIterable, Sendable, Codable {
    case refresh
    case cachePrune = "cache-prune"
    case launchServicesReset = "launch-services-reset"

    public var requiresReboot: Bool {
        switch self {
        case .refresh:
            return false
        case .cachePrune, .launchServicesReset:
            return true
        }
    }
}

public struct LifecycleOperationSpec: Sendable, Equatable, Codable {
    public let intent: LifecycleIntent
    public let scope: LifecycleScope
    public let dataPolicy: LifecycleDataPolicy
    public let resetDepth: LifecycleResetDepth

    private init(
        intent: LifecycleIntent,
        scope: LifecycleScope,
        dataPolicy: LifecycleDataPolicy,
        resetDepth: LifecycleResetDepth
    ) {
        self.intent = intent
        self.scope = scope
        self.dataPolicy = dataPolicy
        self.resetDepth = resetDepth
    }

    public static func install(scope: LifecycleScope = .user) -> LifecycleOperationSpec {
        LifecycleOperationSpec(
            intent: .install,
            scope: scope,
            dataPolicy: .preserve,
            resetDepth: .refresh
        )
    }

    public static func remove(
        scope: LifecycleScope = .user,
        dataPolicy: LifecycleDataPolicy = .preserve
    ) -> LifecycleOperationSpec {
        LifecycleOperationSpec(
            intent: .remove,
            scope: scope,
            dataPolicy: dataPolicy,
            resetDepth: .refresh
        )
    }

    public static func reset(
        scope: LifecycleScope = .all,
        depth: LifecycleResetDepth
    ) -> LifecycleOperationSpec {
        LifecycleOperationSpec(
            intent: .reset,
            scope: scope,
            dataPolicy: .preserve,
            resetDepth: depth
        )
    }

    public static func prepareRelease(scope: LifecycleScope = .all) -> LifecycleOperationSpec {
        LifecycleOperationSpec(
            intent: .prepareRelease,
            scope: scope,
            dataPolicy: .purge,
            resetDepth: .refresh
        )
    }

    public var requiresRootPrivileges: Bool {
        switch intent {
        case .install, .remove, .prepareRelease:
            return scope.requiresRootPrivileges
        case .reset:
            return scope.requiresRootPrivileges || resetDepth != .refresh
        }
    }

    public var requiresReboot: Bool {
        intent == .reset && resetDepth.requiresReboot
    }

    public var actionText: String {
        switch intent {
        case .install:
            return "install(scope: \(scope.rawValue))"
        case .remove:
            return "remove(scope: \(scope.rawValue), data: \(dataPolicy.rawValue))"
        case .reset:
            return "reset(scope: \(scope.rawValue), depth: \(resetDepth.rawValue))"
        case .prepareRelease:
            return "prepare-release(scope: \(scope.rawValue))"
        }
    }

    public func commandLine(includeConfirm: Bool = false) -> String {
        var parts = ["swift run bilinectl"]
        switch intent {
        case .install:
            parts += ["install", "dev", "--scope", scope.rawValue]
        case .remove:
            parts += ["remove", "dev", "--scope", scope.rawValue, "--data", dataPolicy.rawValue]
        case .reset:
            parts += ["reset", "dev", "--scope", scope.rawValue, "--depth", resetDepth.rawValue]
        case .prepareRelease:
            parts += ["prepare-release", "dev", "--scope", scope.rawValue]
        }
        if includeConfirm {
            parts.append("--confirm")
        }
        return parts.joined(separator: " ")
    }
}

public enum LifecycleStepKind: String, Sendable {
    case build
    case terminate
    case unregister
    case remove
    case purgeData
    case install
    case register
    case refresh
    case cacheCleanup
    case receipt
    case reboot
    case manualHostGate
    case preserve
}

public struct LifecycleBundleInstallPair: Sendable, Equatable {
    public let source: URL
    public let destination: URL
}

public struct LifecycleBrokerInstall: Sendable, Equatable {
    public let executableSource: URL
    public let executableDestination: URL
    public let launchAgentDestination: URL
    public let launchAgentLabel: String
    public let scope: LifecycleScope
}

public enum LifecycleStepAction: Sendable, Equatable {
    case buildApps
    case buildBroker
    case terminateProcesses
    case unregister([URL])
    case remove([URL], useSudo: Bool)
    case purgeData([URL])
    case purgeSharedConfiguration(String)
    case clearCredentials(String)
    case installBundles([LifecycleBundleInstallPair])
    case installBroker([LifecycleBrokerInstall])
    case removeBroker([LifecycleBrokerInstall])
    case register([URL])
    case pruneHitoolbox
    case clearIntlDataCache
    case resetLaunchServices
    case refreshAgents
    case forgetPackageReceipt(String)
    case noteOnly
}

public struct LifecycleStep: Sendable, Equatable {
    public let kind: LifecycleStepKind
    public let summary: String
    public let action: LifecycleStepAction
}

public struct LifecycleOperationPlan: Sendable, Equatable {
    public let spec: LifecycleOperationSpec
    public let steps: [LifecycleStep]

    public var rendered: String {
        var lines = [
            "operation=\(spec.intent.rawValue) dev",
            "scope=\(spec.scope.rawValue)",
            "data_policy=\(spec.dataPolicy.rawValue)",
            "reset_depth=\(spec.resetDepth.rawValue)",
            "reboot_required=\(spec.requiresReboot ? "true" : "false")",
        ]
        for (index, step) in steps.enumerated() {
            lines.append("\(index + 1). [\(step.kind.rawValue)] \(step.summary)")
        }
        return lines.joined(separator: "\n")
    }
}

public struct LifecycleOperationPlanner: Sendable {
    public let paths: BilineOperationPaths

    public init(paths: BilineOperationPaths = BilineOperationPaths()) {
        self.paths = paths
    }

    public func plan(_ spec: LifecycleOperationSpec) -> LifecycleOperationPlan {
        switch spec.intent {
        case .install:
            return LifecycleOperationPlan(spec: spec, steps: installSteps(scope: spec.scope))
        case .remove:
            return LifecycleOperationPlan(
                spec: spec,
                steps: removeSteps(scope: spec.scope, dataPolicy: spec.dataPolicy)
            )
        case .reset:
            return LifecycleOperationPlan(
                spec: spec,
                steps: resetSteps(scope: spec.scope, depth: spec.resetDepth)
            )
        case .prepareRelease:
            return LifecycleOperationPlan(spec: spec, steps: prepareReleaseSteps(scope: spec.scope))
        }
    }

    private func installSteps(scope: LifecycleScope) -> [LifecycleStep] {
        let installPairs = installBundlePairs(for: scope)
        let installURLs = installPairs.map(\.destination)
        let unregisterURLs = unregisterURLs(for: scope)
        let brokerInstalls = brokerInstalls(for: scope)
        return [
            LifecycleStep(
                kind: .build,
                summary: "Build BilineIMEDev and BilineSettingsDev from the current checkout.",
                action: .buildApps
            ),
            LifecycleStep(
                kind: .build,
                summary: "Build BilineBrokerDev for the user-scoped communication broker.",
                action: .buildBroker
            ),
            LifecycleStep(
                kind: .terminate,
                summary: "Stop BilineIMEDev and BilineSettingsDev if they are running.",
                action: .terminateProcesses
            ),
            LifecycleStep(
                kind: .unregister,
                summary: "Unregister dev IME and Settings App LaunchServices paths for \(scope.rawValue) scope plus legacy build paths.",
                action: .unregister(unregisterURLs)
            ),
            LifecycleStep(
                kind: .install,
                summary: "Replace \(joinedPaths(installURLs)).",
                action: .installBundles(installPairs)
            ),
            LifecycleStep(
                kind: .install,
                summary: "Install broker executable and LaunchAgent at \(joinedPaths(brokerInstalls.map(\.executableDestination) + brokerInstalls.map(\.launchAgentDestination))).",
                action: .installBroker(brokerInstalls)
            ),
            LifecycleStep(
                kind: .register,
                summary: "Register \(scope.rawValue) install paths with LaunchServices.",
                action: .register(installURLs)
            ),
            LifecycleStep(
                kind: .refresh,
                summary: "Refresh LaunchServices and text-input agents without selecting an input source.",
                action: .refreshAgents
            ),
            LifecycleStep(
                kind: .preserve,
                summary: "Preserve Alibaba credentials, Rime userdb, and Biline defaults.",
                action: .noteOnly
            ),
            LifecycleStep(
                kind: .manualHostGate,
                summary: "Stop before real-host input. User manually selects input source, focuses host, types, browses, and commits.",
                action: .noteOnly
            ),
        ]
    }

    private func removeSteps(
        scope: LifecycleScope,
        dataPolicy: LifecycleDataPolicy
    ) -> [LifecycleStep] {
        let removeURLs = installURLs(for: scope)
        let unregisterURLs = unregisterURLs(for: scope)
        let brokerInstalls = brokerInstalls(for: scope)
        var steps: [LifecycleStep] = [
            LifecycleStep(
                kind: .terminate,
                summary: "Stop BilineIMEDev and BilineSettingsDev if they are running.",
                action: .terminateProcesses
            ),
            LifecycleStep(
                kind: .unregister,
                summary: "Unregister dev IME and Settings App LaunchServices paths for \(scope.rawValue) scope plus legacy build paths.",
                action: .unregister(unregisterURLs)
            ),
            LifecycleStep(
                kind: .remove,
                summary: "Remove \(scope.rawValue) install bundles at \(joinedPaths(removeURLs)).",
                action: .remove(removeURLs, useSudo: scope.requiresRootPrivileges)
            ),
            LifecycleStep(
                kind: .remove,
                summary: "Remove broker executable and LaunchAgent for \(scope.rawValue) scope.",
                action: .removeBroker(brokerInstalls)
            ),
        ]

        if scope.requiresRootPrivileges {
            steps.append(
                LifecycleStep(
                    kind: .receipt,
                    summary: "Forget the dev tester package receipt when uninstalling system-scope bundles.",
                    action: .forgetPackageReceipt("io.github.xixiphus.inputmethod.BilineIME.dev.pkg")
                ))
        }

        if dataPolicy == .purge {
            steps.append(
                LifecycleStep(
                    kind: .purgeData,
                    summary: "Purge Biline-local credentials, Rime userdb, preferences, and saved app state.",
                    action: .purgeData(paths.deepCleanDataPaths)
                ))
            steps.append(
                LifecycleStep(
                    kind: .purgeData,
                    summary: "Reset the shared defaults suite for the dev lane.",
                    action: .purgeSharedConfiguration(BilineAppIdentifier.devInputMethodBundle)
                ))
            steps.append(
                LifecycleStep(
                    kind: .purgeData,
                    summary: "Clear shared Aliyun credentials from Keychain.",
                    action: .clearCredentials(BilineAppIdentifier.devInputMethodBundle)
                ))
            steps.append(
                LifecycleStep(
                    kind: .refresh,
                    summary: "Prune Biline HIToolbox state after purging local data.",
                    action: .pruneHitoolbox
                ))
        } else {
            steps.append(
                LifecycleStep(
                    kind: .preserve,
                    summary: "Preserve Alibaba credentials, Rime userdb, and Biline defaults.",
                    action: .noteOnly
                ))
        }

        steps.append(
            LifecycleStep(
                kind: .refresh,
                summary: "Refresh LaunchServices and text-input agents without selecting an input source.",
                action: .refreshAgents
            ))
        steps.append(
            LifecycleStep(
                kind: .manualHostGate,
                summary: "Stop before real-host input. User manually verifies the next install in TextEdit.",
                action: .noteOnly
            ))
        return steps
    }

    private func resetSteps(
        scope: LifecycleScope,
        depth: LifecycleResetDepth
    ) -> [LifecycleStep] {
        let removeURLs = installURLs(for: scope)
        let unregisterURLs = unregisterURLs(for: scope)
        let brokerInstalls = brokerInstalls(for: scope)
        var steps: [LifecycleStep] = [
            LifecycleStep(
                kind: .terminate,
                summary: "Stop BilineIMEDev and BilineSettingsDev if they are running.",
                action: .terminateProcesses
            ),
            LifecycleStep(
                kind: .unregister,
                summary: "Unregister dev IME and Settings App LaunchServices paths for \(scope.rawValue) scope plus legacy build paths.",
                action: .unregister(unregisterURLs)
            ),
            LifecycleStep(
                kind: .remove,
                summary: "Remove installed dev bundles at \(joinedPaths(removeURLs)).",
                action: .remove(removeURLs, useSudo: scope.requiresRootPrivileges)
            ),
            LifecycleStep(
                kind: .remove,
                summary: "Remove broker executable and LaunchAgent for \(scope.rawValue) scope.",
                action: .removeBroker(brokerInstalls)
            ),
            LifecycleStep(
                kind: .refresh,
                summary: "Prune Biline HIToolbox state.",
                action: .pruneHitoolbox
            ),
        ]

        if scope.requiresRootPrivileges {
            steps.append(
                LifecycleStep(
                    kind: .receipt,
                    summary: "Forget the dev tester package receipt when resetting system-scope bundles.",
                    action: .forgetPackageReceipt("io.github.xixiphus.inputmethod.BilineIME.dev.pkg")
                ))
        }

        if depth == .cachePrune || depth == .launchServicesReset {
            steps.append(
                LifecycleStep(
                    kind: .cacheCleanup,
                    summary: "Clear IntlDataCache before the next install.",
                    action: .clearIntlDataCache
                ))
        }

        if depth == .launchServicesReset {
            steps.append(
                LifecycleStep(
                    kind: .cacheCleanup,
                    summary: "Reset the LaunchServices database with lsregister -delete.",
                    action: .resetLaunchServices
                ))
        }

        steps.append(
            LifecycleStep(
                kind: .refresh,
                summary: "Refresh LaunchServices and text-input agents without selecting an input source.",
                action: .refreshAgents
            ))
        steps.append(
            LifecycleStep(
                kind: .preserve,
                summary: "Preserve Alibaba credentials, Rime userdb, and Biline defaults.",
                action: .noteOnly
            ))
        if depth.requiresReboot {
            steps.append(
                LifecycleStep(
                    kind: .reboot,
                    summary: "Reboot is required before reinstalling dev apps. After reboot, run \(LifecycleOperationSpec.install(scope: .user).commandLine(includeConfirm: true)).",
                    action: .noteOnly
                ))
        }
        return steps
    }

    private func prepareReleaseSteps(scope: LifecycleScope) -> [LifecycleStep] {
        let removeURLs = installURLs(for: scope)
        let unregisterURLs = unregisterURLs(for: scope)
        let brokerInstalls = brokerInstalls(for: scope)
        var steps: [LifecycleStep] = [
            LifecycleStep(
                kind: .terminate,
                summary: "Stop BilineIMEDev and BilineSettingsDev if they are running.",
                action: .terminateProcesses
            ),
            LifecycleStep(
                kind: .unregister,
                summary: "Unregister dev IME and Settings App LaunchServices paths for \(scope.rawValue) scope plus legacy build paths.",
                action: .unregister(unregisterURLs)
            ),
            LifecycleStep(
                kind: .remove,
                summary: "Remove all dev install bundles at \(joinedPaths(removeURLs)).",
                action: .remove(removeURLs, useSudo: scope.requiresRootPrivileges)
            ),
            LifecycleStep(
                kind: .remove,
                summary: "Remove broker executable and LaunchAgent for all installed scopes.",
                action: .removeBroker(brokerInstalls)
            ),
            LifecycleStep(
                kind: .purgeData,
                summary: "Purge Biline-local credentials, Rime userdb, preferences, and saved app state.",
                action: .purgeData(paths.deepCleanDataPaths)
            ),
            LifecycleStep(
                kind: .purgeData,
                summary: "Reset the shared defaults suite for the dev lane.",
                action: .purgeSharedConfiguration(BilineAppIdentifier.devInputMethodBundle)
            ),
            LifecycleStep(
                kind: .purgeData,
                summary: "Clear shared Aliyun credentials from Keychain.",
                action: .clearCredentials(BilineAppIdentifier.devInputMethodBundle)
            ),
            LifecycleStep(
                kind: .refresh,
                summary: "Prune Biline HIToolbox state so release setup starts from a clean input-source list.",
                action: .pruneHitoolbox
            ),
        ]

        if scope.requiresRootPrivileges {
            steps.append(
                LifecycleStep(
                    kind: .receipt,
                    summary: "Forget the dev tester package receipt so future release packages install cleanly.",
                    action: .forgetPackageReceipt("io.github.xixiphus.inputmethod.BilineIME.dev.pkg")
                ))
        }

        steps.append(
            LifecycleStep(
                kind: .refresh,
                summary: "Refresh LaunchServices and text-input agents without selecting an input source.",
                action: .refreshAgents
            ))
        steps.append(
            LifecycleStep(
                kind: .manualHostGate,
                summary: "System is ready for a clean release-style install. User manually adds the next input source after installation.",
                action: .noteOnly
            ))
        return steps
    }

    private func installBundlePairs(for scope: LifecycleScope) -> [LifecycleBundleInstallPair] {
        scope.surfaces.flatMap { surface in
            [
                LifecycleBundleInstallPair(
                    source: paths.devInputMethodBuildURL,
                    destination: BilineAppPath.devInputMethodInstallURL(
                        surface: surface,
                        homeDirectory: paths.homeDirectory
                    )
                ),
                LifecycleBundleInstallPair(
                    source: paths.devSettingsBuildURL,
                    destination: BilineAppPath.devSettingsInstallURL(
                        surface: surface,
                        homeDirectory: paths.homeDirectory
                    )
                ),
            ]
        }
    }

    private func installURLs(for scope: LifecycleScope) -> [URL] {
        installBundlePairs(for: scope).map(\.destination)
    }

    private func unregisterURLs(for scope: LifecycleScope) -> [URL] {
        uniqueURLs(paths.legacyDevInputMethodURLs + paths.legacyDevSettingsURLs + installURLs(for: scope))
    }

    private func joinedPaths(_ urls: [URL]) -> String {
        urls.map(\.path).joined(separator: " and ")
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            if seen.insert(url.path).inserted {
                result.append(url)
            }
        }
        return result
    }

    private func brokerInstalls(for scope: LifecycleScope) -> [LifecycleBrokerInstall] {
        scope.surfaces.map { surface in
            LifecycleBrokerInstall(
                executableSource: paths.devBrokerBuildURL,
                executableDestination: surface == .user
                    ? paths.devBrokerInstallURL
                    : paths.packagedDevBrokerInstallURL,
                launchAgentDestination: BilineAppPath.devBrokerLaunchAgentURL(
                    surface: surface,
                    homeDirectory: paths.homeDirectory
                ),
                launchAgentLabel: BilineSharedIdentifier.brokerLaunchAgentLabel(
                    for: BilineAppIdentifier.devInputMethodBundle
                ),
                scope: surface == .user ? .user : .system
            )
        }
    }
}
