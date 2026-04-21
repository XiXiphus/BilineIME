import BilineCore
import Foundation

/// Reads and writes a `KeyBindingPolicy` to/from the IME's defaults domain.
///
/// We store the entire policy as a single JSON blob under
/// `BilineDefaultsKey.keyBindingPolicy`. That keeps cross-process writes
/// atomic from the reader's perspective and avoids a fan-out of one defaults
/// key per binding role (which would otherwise need its own migration plan
/// each time we add a role in a later phase).
public enum KeyBindingDefaults {
    public static func load(from store: BilineDefaultsStore) -> KeyBindingPolicy {
        guard let data = store.data(forKey: BilineDefaultsKey.keyBindingPolicy) else {
            return .default
        }
        do {
            return try KeyBindingPolicy.decode(data)
        } catch {
            return .default
        }
    }

    public static func save(_ policy: KeyBindingPolicy, into store: BilineDefaultsStore) {
        do {
            let data = try policy.encode()
            store.set(data, forKey: BilineDefaultsKey.keyBindingPolicy)
            store.synchronize()
        } catch {
            // Encoding is deterministic for the value type; failure is
            // non-recoverable. We deliberately drop the write rather than
            // blowing up the Settings App.
        }
    }
}
