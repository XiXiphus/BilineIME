import BilineCore
import BilinePreview
import Foundation

/// Settings store used by the running IME. Holds an immutable snapshot,
/// rebuilds it from the IME's defaults domain on `refresh()`, and notifies
/// `onChange` subscribers when the snapshot actually differs from the
/// previous one.
///
/// Why this lives in `BilineSettings` (not the App): the controller's hot
/// path needs only constant-time field reads from the snapshot. Moving the
/// type into the package makes it unit-testable without spinning up the
/// IMK process and lets future tooling (e.g. `bilinectl`) load the same
/// snapshot without duplicating defaults parsing.
public final class LiveSettingsStore: SettingsStore, @unchecked Sendable {
    private let defaults: BilineDefaultsStore?
    private let snapshotLoader: () -> SettingsSnapshot
    private let lock = NSLock()
    private var cached: SettingsSnapshot

    /// Fired whenever `refresh()` observes a change. The callback runs on the
    /// thread that called `refresh()`; the controller hops to main before
    /// touching AppKit views.
    public var onChange: ((SettingsSnapshot) -> Void)?

    public init(domain: String) {
        let defaults = BilineDefaultsStore(domain: domain)
        defaults.synchronize()
        self.defaults = defaults
        self.snapshotLoader = { SettingsSnapshot.load(from: defaults) }
        self.cached = self.snapshotLoader()
    }

    public init(defaults: BilineDefaultsStore) {
        defaults.synchronize()
        self.defaults = defaults
        self.snapshotLoader = { SettingsSnapshot.load(from: defaults) }
        self.cached = self.snapshotLoader()
    }

    public init(snapshotLoader: @escaping () -> SettingsSnapshot) {
        self.defaults = nil
        self.snapshotLoader = snapshotLoader
        self.cached = snapshotLoader()
    }

    public var snapshot: SettingsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    /// Re-reads the IME's defaults domain. Returns true and notifies
    /// subscribers when the snapshot actually changed. Cheap enough to call
    /// at lifecycle boundaries (`activateServer`, `commitComposition`) but
    /// not from inside the keystroke hot path.
    @discardableResult
    public func refresh() -> Bool {
        defaults?.synchronize()
        let next = snapshotLoader()
        lock.lock()
        let changed = next != cached
        if changed {
            cached = next
        }
        lock.unlock()
        if changed {
            onChange?(next)
        }
        return changed
    }

    public var targetLanguage: TargetLanguage { .english }
    public var previewEnabled: Bool { snapshot.previewEnabled && snapshot.bilingualModeEnabled }
    public var bilingualModeEnabled: Bool { snapshot.bilingualModeEnabled }
    public var compactColumnCount: Int { max(1, snapshot.compactColumnCount) }
    public var expandedRowCount: Int { max(1, snapshot.expandedRowCount) }
    public var fuzzyPinyinEnabled: Bool { snapshot.fuzzyPinyinEnabled }
    public var characterForm: CharacterForm { snapshot.characterForm }
    public var punctuationForm: PunctuationForm { snapshot.punctuationForm }
    public var pageSize: Int { snapshot.pageSize }
    public var keyBindings: KeyBindingPolicy { snapshot.keyBindings }
}
