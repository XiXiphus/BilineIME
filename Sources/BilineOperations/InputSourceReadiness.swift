import BilineSettings
import Carbon
import Foundation

/// Where the BilineIME input source is in the user-driven onboarding flow.
///
/// Apple's user-facing model treats "installing the input method bundle" and
/// "having the input method appear in System Settings → Keyboard → Input
/// Sources as an enabled, selectable source" as two distinct steps. This enum
/// makes that boundary explicit so that automated host smoke can fail fast
/// with a precise reason and remediation hint instead of getting stuck on
/// generic "the source is missing" errors.
public enum BilineInputSourceReadinessState: String, Codable, CaseIterable, Sendable {
    /// The IME app bundle itself is not installed, so the source can never
    /// register. Run `bilinectl install dev --confirm` first.
    case bundleMissing

    /// The bundle is installed but the OS has not registered the input source
    /// yet. The user typically needs to log out / back in once after install.
    case sourceMissing

    /// The source is registered but disabled. The user must enable it in
    /// System Settings → Keyboard → Input Sources.
    case sourceDisabled

    /// The source is enabled but cannot be selected for input (rare; usually
    /// indicates a malformed Info.plist or bundle layout).
    case sourceNotSelectable

    /// The source is enabled and selectable but the current keyboard input
    /// source is something else. Host smoke can still proceed because the
    /// harness will switch to it programmatically before driving the host.
    case sourceNotSelected

    /// The source exists, is enabled, is selectable, and is currently active.
    case ready
}

extension BilineInputSourceReadinessState {
    /// Whether host smoke can proceed without manual intervention.
    /// `sourceNotSelected` is treated as ready because the harness will
    /// programmatically select the source as part of normal smoke setup.
    public var isReady: Bool {
        switch self {
        case .ready, .sourceNotSelected:
            return true
        case .bundleMissing, .sourceMissing, .sourceDisabled, .sourceNotSelectable:
            return false
        }
    }

    public var shortDescription: String {
        switch self {
        case .bundleMissing: return "bundle-missing"
        case .sourceMissing: return "source-missing"
        case .sourceDisabled: return "source-disabled"
        case .sourceNotSelectable: return "source-not-selectable"
        case .sourceNotSelected: return "source-not-selected"
        case .ready: return "ready"
        }
    }
}

public struct BilineInputSourceSnapshot: Sendable, Equatable, Codable {
    public let id: String
    public let localizedName: String
    public let enabled: Bool
    public let selectable: Bool
    public let selected: Bool

    public init(
        id: String,
        localizedName: String,
        enabled: Bool,
        selectable: Bool,
        selected: Bool
    ) {
        self.id = id
        self.localizedName = localizedName
        self.enabled = enabled
        self.selectable = selectable
        self.selected = selected
    }
}

public protocol BilineInputSourceQuerying: Sendable {
    func currentInputSourceID() -> String?
    func snapshot(for inputSourceID: String) -> BilineInputSourceSnapshot?
}

public struct CarbonInputSourceQuery: BilineInputSourceQuerying {
    public init() {}

    public func currentInputSourceID() -> String? {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return Self.value(current, kTISPropertyInputSourceID) as? String
    }

    public func snapshot(for inputSourceID: String) -> BilineInputSourceSnapshot? {
        guard let source = Self.findSource(inputSourceID) else { return nil }
        return BilineInputSourceSnapshot(
            id: Self.value(source, kTISPropertyInputSourceID) as? String ?? inputSourceID,
            localizedName: Self.value(source, kTISPropertyLocalizedName) as? String ?? "",
            enabled: Self.value(source, kTISPropertyInputSourceIsEnabled) as? Bool ?? false,
            selectable: Self.value(source, kTISPropertyInputSourceIsSelectCapable) as? Bool ?? false,
            selected: Self.value(source, kTISPropertyInputSourceIsSelected) as? Bool ?? false
        )
    }

    fileprivate static func value(_ source: TISInputSource, _ key: CFString) -> Any? {
        guard let unmanaged = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(unmanaged).takeUnretainedValue()
    }

    fileprivate static func findSource(_ inputSourceID: String) -> TISInputSource? {
        let list =
            (TISCreateInputSourceList(nil, true).takeRetainedValue() as NSArray)
            as! [TISInputSource]
        return list.first(where: {
            (value($0, kTISPropertyInputSourceID) as? String) == inputSourceID
        })
    }
}

public struct BilineInputSourceReadinessReport: Codable, Sendable, Equatable {
    public let state: BilineInputSourceReadinessState
    public let inputSourceID: String
    public let bundleIdentifier: String
    public let bundleInstalled: Bool
    public let snapshot: BilineInputSourceSnapshot?
    public let currentInputSourceID: String?
    public let summary: String
    public let remediation: [String]

    public init(
        state: BilineInputSourceReadinessState,
        inputSourceID: String,
        bundleIdentifier: String,
        bundleInstalled: Bool,
        snapshot: BilineInputSourceSnapshot?,
        currentInputSourceID: String?,
        summary: String,
        remediation: [String]
    ) {
        self.state = state
        self.inputSourceID = inputSourceID
        self.bundleIdentifier = bundleIdentifier
        self.bundleInstalled = bundleInstalled
        self.snapshot = snapshot
        self.currentInputSourceID = currentInputSourceID
        self.summary = summary
        self.remediation = remediation
    }

    public var isReady: Bool { state.isReady }
}

public struct BilineInputSourceReadinessChecker: Sendable {
    public let inputSourceID: String
    public let bundleIdentifier: String
    public let displayName: String
    private let query: any BilineInputSourceQuerying

    public init(
        inputSourceID: String = BilineAppIdentifier.devInputSource,
        bundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        displayName: String = "BilineIME Dev",
        query: any BilineInputSourceQuerying = CarbonInputSourceQuery()
    ) {
        self.inputSourceID = inputSourceID
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.query = query
    }

    public func evaluate(bundleInstalled: Bool) -> BilineInputSourceReadinessReport {
        let snapshot = query.snapshot(for: inputSourceID)
        let currentID = query.currentInputSourceID()
        let state = classify(bundleInstalled: bundleInstalled, snapshot: snapshot, currentID: currentID)
        return BilineInputSourceReadinessReport(
            state: state,
            inputSourceID: inputSourceID,
            bundleIdentifier: bundleIdentifier,
            bundleInstalled: bundleInstalled,
            snapshot: snapshot,
            currentInputSourceID: currentID,
            summary: summary(for: state, snapshot: snapshot, currentID: currentID),
            remediation: remediation(for: state, snapshot: snapshot)
        )
    }

    private func classify(
        bundleInstalled: Bool,
        snapshot: BilineInputSourceSnapshot?,
        currentID: String?
    ) -> BilineInputSourceReadinessState {
        guard bundleInstalled else { return .bundleMissing }
        guard let snapshot else { return .sourceMissing }
        guard snapshot.enabled else { return .sourceDisabled }
        guard snapshot.selectable else { return .sourceNotSelectable }
        if currentID == inputSourceID || snapshot.selected {
            return .ready
        }
        return .sourceNotSelected
    }

    private func summary(
        for state: BilineInputSourceReadinessState,
        snapshot: BilineInputSourceSnapshot?,
        currentID: String?
    ) -> String {
        switch state {
        case .bundleMissing:
            return "\(displayName) (\(bundleIdentifier)) is not installed."
        case .sourceMissing:
            return
                "\(displayName) is installed but its input source \(inputSourceID) is not registered yet. macOS usually needs a logout/login or a Launch Services rebuild."
        case .sourceDisabled:
            return
                "\(displayName) input source exists but is disabled. The user must enable it in System Settings → Keyboard → Input Sources."
        case .sourceNotSelectable:
            let name = snapshot?.localizedName ?? displayName
            return
                "\(name) input source is enabled but is reported as non-selectable by Text Input Services. Reinstall and re-enable the source, or rebuild Launch Services."
        case .sourceNotSelected:
            let observed = currentID ?? "<unknown>"
            return
                "\(displayName) input source is enabled and selectable. Current input source is \(observed); the harness can switch to \(inputSourceID) before driving the host."
        case .ready:
            return "\(displayName) is enabled, selectable, and currently active."
        }
    }

    private func remediation(
        for state: BilineInputSourceReadinessState,
        snapshot: BilineInputSourceSnapshot?
    ) -> [String] {
        switch state {
        case .bundleMissing:
            return [
                "Run `make install-ime` (or `bilinectl install dev --confirm`).",
                "If the install reports success but the bundle is still missing, run `make diagnose-ime` and share the output.",
            ]
        case .sourceMissing:
            return [
                "Log out and log back in once after the first install so macOS picks up the new input source.",
                "If the source still does not appear, run `make reset-ime CONFIRM=1 RESET_DEPTH=cache-prune` and then add it again.",
                "Open System Settings → Keyboard → Input Sources and click the + button to add `\(displayName)` manually.",
            ]
        case .sourceDisabled:
            return [
                "Open System Settings → Keyboard → Input Sources.",
                "Find `\(displayName)` in the list and enable the checkbox so it appears in the menu bar input picker.",
                "If macOS shows an `Allow / Don't Allow` prompt for the input method, click Allow manually; do not script that prompt.",
            ]
        case .sourceNotSelectable:
            return [
                "Run `make remove-ime` followed by `make install-ime` to reinstall a clean bundle.",
                "If the symptom persists, run `make reset-ime CONFIRM=1 RESET_DEPTH=launch-services-reset` and reboot.",
                "Then re-add `\(displayName)` from System Settings → Keyboard → Input Sources.",
            ]
        case .sourceNotSelected:
            let name = snapshot?.localizedName ?? displayName
            return [
                "No manual action required: host smoke will switch to `\(name)` programmatically.",
                "If you want to verify manually, click the input picker in the menu bar and choose `\(name)` first.",
            ]
        case .ready:
            return []
        }
    }
}
