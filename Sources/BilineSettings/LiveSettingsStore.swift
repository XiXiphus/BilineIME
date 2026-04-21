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
    private let defaults: BilineDefaultsStore
    private let lock = NSLock()
    private var cached: SettingsSnapshot

    /// Fired whenever `refresh()` observes a change. The callback runs on the
    /// thread that called `refresh()`; the controller hops to main before
    /// touching AppKit views.
    public var onChange: ((SettingsSnapshot) -> Void)?

    public init(domain: String) {
        self.defaults = BilineDefaultsStore(domain: domain)
        self.defaults.synchronize()
        self.cached = SettingsSnapshot.load(from: self.defaults)
    }

    public init(defaults: BilineDefaultsStore) {
        self.defaults = defaults
        self.defaults.synchronize()
        self.cached = SettingsSnapshot.load(from: self.defaults)
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
        defaults.synchronize()
        let next = SettingsSnapshot.load(from: defaults)
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
    /// Effective preview gate. Offline mode (`单机模式`) forcibly disables
    /// preview regardless of the user's `previewEnabled` toggle, so the IME
    /// makes zero outbound network calls when the user has opted out.
    public var previewEnabled: Bool {
        let s = snapshot
        return s.previewEnabled && !s.offlineMode
    }
    public var compactColumnCount: Int { max(1, snapshot.compactColumnCount) }
    public var expandedRowCount: Int { max(1, snapshot.expandedRowCount) }
    public var fuzzyPinyinEnabled: Bool { snapshot.fuzzyPinyinEnabled }
    public var characterForm: CharacterForm { snapshot.characterForm }
    public var punctuationForm: PunctuationForm { snapshot.punctuationForm }
    public var pageSize: Int { snapshot.pageSize }
    public var keyBindings: KeyBindingPolicy { snapshot.keyBindings }
}
