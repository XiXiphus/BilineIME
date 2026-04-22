import BilineCore
import BilineSettings
import XCTest

final class LiveSettingsStoreTests: XCTestCase {
    private var domain: String!

    override func setUp() {
        super.setUp()
        // Each test gets its own isolated CFPreferences domain so writes
        // never bleed into the user's real IME defaults. Using a UUID keeps
        // the suite parallel-safe.
        domain = "io.github.xixiphus.inputmethod.BilineIME.tests.\(UUID().uuidString)"
    }

    override func tearDown() {
        let store = BilineDefaultsStore(domain: domain)
        let allKeys: [String] = [
            BilineDefaultsKey.previewEnabled,
            BilineDefaultsKey.bilingualModeEnabled,
            BilineDefaultsKey.didSeedBilingualModeDefault,
            BilineDefaultsKey.compactColumnCount,
            BilineDefaultsKey.expandedRowCount,
            BilineDefaultsKey.fuzzyPinyinEnabled,
            BilineDefaultsKey.characterForm,
            BilineDefaultsKey.punctuationForm,
            BilineDefaultsKey.keyBindingPolicy,
            BilineDefaultsKey.panelThemeMode,
            BilineDefaultsKey.panelFontScale,
        ]
        for key in allKeys {
            store.removeValue(forKey: key)
        }
        store.synchronize()
        super.tearDown()
    }

    func testInitialSnapshotMatchesShippedDefaultsWhenStorageIsEmpty() {
        let store = LiveSettingsStore(domain: domain)
        XCTAssertEqual(store.previewEnabled, false)
        XCTAssertEqual(store.bilingualModeEnabled, false)
        XCTAssertEqual(store.compactColumnCount, 5)
        XCTAssertEqual(store.expandedRowCount, 5)
        XCTAssertEqual(store.fuzzyPinyinEnabled, false)
        XCTAssertEqual(store.characterForm, .simplified)
        XCTAssertEqual(store.punctuationForm, .fullwidth)
        XCTAssertEqual(store.keyBindings, .default)
    }

    func testRefreshObservesExternalWritesAndPublishesChange() {
        let store = LiveSettingsStore(domain: domain)
        let writer = BilineDefaultsStore(domain: domain)
        let received = LockedSnapshotRecorder()
        store.onChange = { snapshot in
            received.append(snapshot)
        }

        writer.set("traditional", forKey: BilineDefaultsKey.characterForm)
        writer.set(3, forKey: BilineDefaultsKey.compactColumnCount)
        writer.synchronize()

        XCTAssertTrue(store.refresh())
        XCTAssertEqual(received.snapshots.count, 1)
        XCTAssertEqual(store.characterForm, .traditional)
        XCTAssertEqual(store.compactColumnCount, 3)
    }

    func testRefreshIsNoOpWhenNothingChanged() {
        let store = LiveSettingsStore(domain: domain)
        let received = LockedSnapshotRecorder()
        store.onChange = { snapshot in
            received.append(snapshot)
        }

        // First refresh after init: storage is unchanged from snapshot we
        // already loaded, so no callback fires.
        XCTAssertFalse(store.refresh())
        XCTAssertTrue(received.snapshots.isEmpty)
    }

    func testKeyBindingPolicyRoundTripsThroughDefaults() throws {
        let writer = BilineDefaultsStore(domain: domain)
        let custom = KeyBindingPolicy(bindings: [
            .candidate2: [KeyChord(character: ";")],
            .candidate3: [KeyChord(character: "'")],
        ])
        KeyBindingDefaults.save(custom, into: writer)

        let store = LiveSettingsStore(domain: domain)
        XCTAssertEqual(store.keyBindings, custom)
    }

    func testInvalidKeyBindingBlobFallsBackToDefault() {
        let writer = BilineDefaultsStore(domain: domain)
        writer.set(Data([0x00, 0xFF, 0x00]), forKey: BilineDefaultsKey.keyBindingPolicy)
        writer.synchronize()

        let store = LiveSettingsStore(domain: domain)
        XCTAssertEqual(store.keyBindings, .default)
    }

    func testPanelFontScaleAndThemeModeAreLoaded() {
        let writer = BilineDefaultsStore(domain: domain)
        writer.set("dark", forKey: BilineDefaultsKey.panelThemeMode)
        writer.set(1.4, forKey: BilineDefaultsKey.panelFontScale)
        writer.synchronize()

        let store = LiveSettingsStore(domain: domain)
        XCTAssertEqual(store.snapshot.panelThemeMode, .dark)
        XCTAssertEqual(store.snapshot.panelFontScale, 1.4, accuracy: 0.0001)
    }

    func testFreshInstallSeedsPurePinyinModeOff() {
        let homeURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: homeURL) }
        try? FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)

        let defaults = BilineDefaultsStore(domain: domain)
        let snapshot = SettingsSnapshot.load(from: defaults, homeDirectory: homeURL)

        XCTAssertFalse(snapshot.bilingualModeEnabled)
        XCTAssertFalse(defaults.bool(forKey: BilineDefaultsKey.bilingualModeEnabled) ?? true)
        XCTAssertTrue(defaults.bool(forKey: BilineDefaultsKey.didSeedBilingualModeDefault) ?? false)
    }

    func testExistingInstallSignalKeepsBilingualModeEnabled() throws {
        let homeURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: homeURL) }
        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)

        let defaults = BilineDefaultsStore(domain: domain)
        let legacyPreferenceURL = BilineAppPath.preferenceFileURL(domain: domain, homeDirectory: homeURL)
        try FileManager.default.createDirectory(
            at: legacyPreferenceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("legacy".utf8).write(to: legacyPreferenceURL)

        let snapshot = SettingsSnapshot.load(from: defaults, homeDirectory: homeURL)

        XCTAssertTrue(snapshot.bilingualModeEnabled)
        XCTAssertTrue(defaults.bool(forKey: BilineDefaultsKey.bilingualModeEnabled) ?? false)
    }
}

private final class LockedSnapshotRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [SettingsSnapshot] = []

    func append(_ snapshot: SettingsSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(snapshot)
    }

    var snapshots: [SettingsSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
