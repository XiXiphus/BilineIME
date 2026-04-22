import BilineOperations
import AppKit
import Foundation

extension BilineCtl {
    static func smokeHost(arguments: [String]) throws -> String {
        guard arguments.count >= 2, arguments[0] == "smoke-host", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }

        let homeDirectory = try parseHomeDirectory(arguments)
        let paths = BilineOperationPaths(homeDirectory: homeDirectory)

        if arguments.contains("--check") {
            return checkInputSourceReadiness(paths: paths)
        }
        if arguments.contains("--prepare") {
            return prepareInputSourceReadiness(paths: paths)
        }

        guard arguments.contains("--confirm") else {
            throw BilineOperationError.confirmationRequiredForAction("smoke-host dev")
        }

        if arguments.contains("--install") {
            throw BilineOperationError.unsupportedArguments(
                """
                The --install flag has been removed from `smoke-host`.
                Install and source enrollment are separate phases now:
                  1. Run `bilinectl install dev --confirm` (or `make install-ime`).
                  2. Manually enable BilineIME Dev in System Settings → Keyboard → Input Sources.
                  3. Run `bilinectl smoke-host dev --check` (or `make smoke-ime-host-check`).
                  4. Run `bilinectl smoke-host dev --confirm` (or `make smoke-ime-host`).
                """
            )
        }

        let scenario = try parseHostSmokeScenario(arguments)
        return try HostSmokeHarness(paths: paths, scenario: scenario).run()
    }

    fileprivate static func parseHostSmokeScenario(_ arguments: [String]) throws
        -> HostSmokeScenario
    {
        guard let value = try value(forFlag: "--scenario", in: arguments) else {
            return .full
        }
        guard let scenario = HostSmokeScenario(rawValue: value) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --scenario candidate-popup|browse|commit|settings-refresh|full.\n\(usage)"
            )
        }
        return scenario
    }

    private static func checkInputSourceReadiness(paths: BilineOperationPaths) -> String {
        let snapshot = DevEnvironmentDiagnostics(paths: paths).snapshot()
        return renderReadinessReport(snapshot.inputSourceReadiness, header: "Input source readiness check")
    }

    private static func prepareInputSourceReadiness(paths: BilineOperationPaths) -> String {
        let initial = DevEnvironmentDiagnostics(paths: paths).snapshot().inputSourceReadiness
        if initial.isReady {
            return renderReadinessReport(
                initial,
                header: "Input source already ready; no manual onboarding required"
            )
        }

        var lines: [String] = []
        lines.append(renderReadinessReport(initial, header: "Input source readiness before assist"))
        lines.append("")

        if initial.state == .bundleMissing {
            lines.append(
                "Bundle missing: refusing to open System Settings because there is no input method to enable yet."
            )
            lines.append(
                "Run `make install-ime` (or `bilinectl install dev --confirm`) first, then re-run `bilinectl smoke-host dev --prepare`."
            )
            return lines.joined(separator: "\n")
        }

        let openedSettings = openInputSourcesSettings()
        if openedSettings {
            lines.append("Opened System Settings → Keyboard → Input Sources.")
        } else {
            lines.append(
                "Could not open System Settings automatically. Open it manually: System Settings → Keyboard → Input Sources."
            )
        }
        lines.append(
            "This helper does NOT click `Allow`, does NOT enable the source, and does NOT switch the active input source for you."
        )
        lines.append("Apple expects this onboarding step to be performed by the user once.")
        lines.append("")

        let recheck = DevEnvironmentDiagnostics(paths: paths).snapshot().inputSourceReadiness
        lines.append(
            renderReadinessReport(recheck, header: "Input source readiness after assist")
        )
        if !recheck.isReady {
            lines.append("")
            lines.append(
                "Source is still not ready. Finish the manual steps above, then re-run `bilinectl smoke-host dev --check` (or `make smoke-ime-host-check`)."
            )
        } else {
            lines.append("")
            lines.append(
                "Source is now ready. You can proceed with `bilinectl smoke-host dev --confirm` (or `make smoke-ime-host`)."
            )
        }
        return lines.joined(separator: "\n")
    }

    private static func openInputSourcesSettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?InputSources",
            "x-apple.systempreferences:com.apple.preference.keyboard?InputSources",
            "x-apple.systempreferences:com.apple.preference.keyboard",
        ]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    static func formatReadinessFailure(_ report: BilineInputSourceReadinessReport) -> String {
        var lines: [String] = []
        lines.append(
            "Host smoke aborted: BilineIME input source is not ready (state=\(report.state.shortDescription))."
        )
        lines.append(report.summary)
        if !report.remediation.isEmpty {
            lines.append("Remediation:")
            for hint in report.remediation {
                lines.append("  - \(hint)")
            }
        }
        lines.append(
            "Re-evaluate with `bilinectl smoke-host dev --check`, or open System Settings → Keyboard → Input Sources via `bilinectl smoke-host dev --prepare`."
        )
        return lines.joined(separator: "\n")
    }

    private static func renderReadinessReport(
        _ report: BilineInputSourceReadinessReport,
        header: String
    ) -> String {
        var lines: [String] = [
            "== \(header) ==",
            "state=\(report.state.shortDescription)",
            "ready=\(report.isReady)",
            "input_source_id=\(report.inputSourceID)",
            "bundle_identifier=\(report.bundleIdentifier)",
            "bundle_installed=\(report.bundleInstalled)",
        ]
        if let snapshot = report.snapshot {
            lines.append(
                "source_localized_name=\(snapshot.localizedName.isEmpty ? "<empty>" : snapshot.localizedName)"
            )
            lines.append("source_enabled=\(snapshot.enabled)")
            lines.append("source_selectable=\(snapshot.selectable)")
            lines.append("source_selected=\(snapshot.selected)")
        } else {
            lines.append("source_registered=false")
        }
        lines.append("current_input_source=\(report.currentInputSourceID ?? "<unknown>")")
        lines.append("summary=\(report.summary)")
        if report.remediation.isEmpty {
            lines.append("remediation=none")
        } else {
            lines.append("remediation:")
            for hint in report.remediation {
                lines.append("  - \(hint)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
