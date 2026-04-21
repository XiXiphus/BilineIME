import Foundation

public enum BilinePlanStepKind: String, Sendable {
    case build
    case terminate
    case unregister
    case remove
    case install
    case register
    case refresh
    case preserve
    case reboot
    case manualHostGate
}

public struct BilinePlanStep: Sendable, Equatable {
    public let kind: BilinePlanStepKind
    public let summary: String
}

public struct BilineReinstallPlan: Sendable, Equatable {
    public let level: BilineOperationLevel
    public let steps: [BilinePlanStep]
    public let requiresRebootBeforeInstall: Bool

    public var rendered: String {
        var lines = ["reinstall dev level=\(level.rawValue)"]
        lines.append(
            "requires_reboot_before_install=\(requiresRebootBeforeInstall ? "true" : "false")")
        for (index, step) in steps.enumerated() {
            lines.append("\(index + 1). [\(step.kind.rawValue)] \(step.summary)")
        }
        return lines.joined(separator: "\n")
    }
}

public struct DevReinstallPlanner: Sendable {
    public let paths: BilineOperationPaths

    public init(paths: BilineOperationPaths = BilineOperationPaths()) {
        self.paths = paths
    }

    public func plan(level: BilineOperationLevel) -> BilineReinstallPlan {
        switch level {
        case .level1:
            return BilineReinstallPlan(
                level: level,
                steps: level1Steps(),
                requiresRebootBeforeInstall: false
            )
        case .level2:
            return BilineReinstallPlan(
                level: level,
                steps: level2Steps(includeLaunchServicesReset: false),
                requiresRebootBeforeInstall: true
            )
        case .level3:
            return BilineReinstallPlan(
                level: level,
                steps: level2Steps(includeLaunchServicesReset: true),
                requiresRebootBeforeInstall: true
            )
        }
    }

    private func level1Steps() -> [BilinePlanStep] {
        [
            BilinePlanStep(
                kind: .build,
                summary: "Build BilineIMEDev and BilineSettingsDev from the current checkout."),
            BilinePlanStep(
                kind: .terminate,
                summary: "Stop BilineIMEDev and BilineSettingsDev if they are running."),
            BilinePlanStep(
                kind: .unregister,
                summary:
                    "Unregister dev IME and Settings App stable and DerivedData LaunchServices paths."
            ),
            BilinePlanStep(
                kind: .install,
                summary:
                    "Replace \(paths.devInputMethodInstallURL.path) and \(paths.devSettingsInstallURL.path)."
            ),
            BilinePlanStep(
                kind: .register,
                summary: "Register stable dev IME and Settings App paths with LaunchServices."),
            BilinePlanStep(
                kind: .refresh,
                summary:
                    "Refresh LaunchServices and text-input agents without selecting an input source."
            ),
            BilinePlanStep(
                kind: .preserve,
                summary: "Preserve Alibaba credentials, Rime userdb, and Biline defaults."),
            BilinePlanStep(
                kind: .manualHostGate,
                summary:
                    "Stop before real-host input. User manually selects input source, focuses host, types, browses, and commits."
            ),
        ]
    }

    private func level2Steps(includeLaunchServicesReset: Bool) -> [BilinePlanStep] {
        var steps = [
            BilinePlanStep(
                kind: .terminate,
                summary: "Stop BilineIMEDev, BilineSettingsDev, and release BilineIME if running."),
            BilinePlanStep(
                kind: .unregister,
                summary: "Unregister Biline dev/release IME and Settings App LaunchServices paths."),
            BilinePlanStep(
                kind: .remove,
                summary: "Remove dev IME, dev Settings App, and release IME app bundles only."),
            BilinePlanStep(
                kind: .refresh, summary: "Prune Biline HIToolbox state and clear IntlDataCache."),
            BilinePlanStep(
                kind: .preserve,
                summary: "Preserve Alibaba credentials, Rime userdb, and Biline defaults."),
        ]
        if includeLaunchServicesReset {
            steps.append(
                BilinePlanStep(
                    kind: .refresh,
                    summary: "Reset the LaunchServices database with lsregister -delete."))
        }
        steps.append(
            BilinePlanStep(
                kind: .reboot,
                summary:
                    "Reboot is required before reinstalling dev apps. After reboot, run level 1 reinstall."
            ))
        return steps
    }
}
