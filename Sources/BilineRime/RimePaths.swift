import Foundation

struct RimePaths {
    let libraryPath: URL
    let sharedDataDir: URL
    let userDataDir: URL
    let logDir: URL

    static func resolve() throws -> RimePaths {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseDir = appSupport.appendingPathComponent("Rime", isDirectory: true)
        let smokeUserDataDir = UserDefaults.standard.string(forKey: RimeDefaults.smokeUserDataDir)
        let userDataDir =
            smokeUserDataDir.map(URL.init(fileURLWithPath:))
            ?? baseDir.appendingPathComponent("user", isDirectory: true)
        let sharedDataDir = baseDir.appendingPathComponent("shared", isDirectory: true)
        let logDir = baseDir.appendingPathComponent("log", isDirectory: true)

        let fallbackLibrary = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(
                "Library/Caches/BilineIME/RimeVendor/1.16.1/lib/librime.1.dylib")

        let bundleLibrary = Bundle.main.privateFrameworksURL?.appendingPathComponent(
            "librime.1.dylib")
        let resourceLibrary = Bundle.main.resourceURL?.appendingPathComponent(
            "RimeRuntime/librime.1.dylib")
        let libraryPath = [bundleLibrary, resourceLibrary, fallbackLibrary]
            .compactMap { $0 }
            .first { fileManager.fileExists(atPath: $0.path) }

        guard let libraryPath else {
            throw RimeError.missingLibrary(fallbackLibrary)
        }

        return RimePaths(
            libraryPath: libraryPath,
            sharedDataDir: sharedDataDir,
            userDataDir: userDataDir,
            logDir: logDir
        )
    }
}
