import BilinePreview
import CBilineRime
import Foundation

enum RimeError: Error, LocalizedError {
    case missingLibrary(URL)
    case missingResource(String)
    case setupFailed(String)
    case deployFailed(String)
    case sessionCreateFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingLibrary(let url):
            return "Missing librime runtime at \(url.path)"
        case .missingResource(let name):
            return "Missing required Rime resource: \(name)"
        case .setupFailed(let message):
            return "Failed to initialize librime: \(message)"
        case .deployFailed(let message):
            return "Failed to deploy Rime schema: \(message)"
        case .sessionCreateFailed(let message):
            return "Failed to create Rime session: \(message)"
        }
    }
}

struct RimeSettings: Sendable, Equatable {
    let pageSize: Int
    let fuzzyPinyinEnabled: Bool
    let characterForm: CharacterForm
}

private enum RimeDefaults {
    static let smokeUserDataDir = "SmokeRimeUserDataDir"
    static let smokeResetUserData = "SmokeRimeResetUserData"
}

final class RimeRuntime: @unchecked Sendable {
    static let shared = RimeRuntime()

    private var preparedSettings: RimeSettings?
    private var isInitialized = false
    private var paths: RimePaths?
    private var tokenizer: PinyinTokenizer?
    private var lexicon: RimeLexicon?

    func prepare(settings: RimeSettings) throws {
        if isInitialized, preparedSettings == settings {
            return
        }

        let resolvedPaths = try RimePaths.resolve()
        try resolvedPaths.prepareFilesystem(settings: settings)

        if isInitialized {
            BRimeFinalize()
            isInitialized = false
        }

        guard
            BRimeSetup(
                resolvedPaths.libraryPath.path,
                resolvedPaths.sharedDataDir.path,
                resolvedPaths.userDataDir.path,
                resolvedPaths.logDir.path,
                "rime.bilineime"
            )
        else {
            throw RimeError.setupFailed(Self.lastError())
        }

        let schemaPath = resolvedPaths.sharedDataDir
            .appendingPathComponent("biline_pinyin.schema.yaml")
            .path
        guard BRimeDeploySchema(schemaPath) else {
            throw RimeError.deployFailed(Self.lastError())
        }

        tokenizer = try PinyinTokenizer.fromDictionaryFile(
            at: resolvedPaths.sharedDataDir.appendingPathComponent("luna_pinyin.dict.yaml")
        )
        lexicon = try RimeLexicon.fromDictionaryFiles(
            at: [
                resolvedPaths.sharedDataDir.appendingPathComponent("luna_pinyin.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("rime_ice.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/8105.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/base.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/ext.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/tencent.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("cn_dicts/others.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent("biline_phrases.dict.yaml"),
                resolvedPaths.sharedDataDir.appendingPathComponent(
                    "biline_modern_phrases.dict.yaml"),
            ]
        )
        preparedSettings = settings
        paths = resolvedPaths
        isInitialized = true
    }

    func makeSession(schemaID: String, settings: RimeSettings) throws -> BRimeSessionId {
        try prepare(settings: settings)

        let sessionID = BRimeCreateSession()
        guard sessionID != 0 else {
            throw RimeError.sessionCreateFailed(Self.lastError())
        }

        guard BRimeSelectSchema(sessionID, schemaID) else {
            BRimeDestroySession(sessionID)
            throw RimeError.setupFailed(Self.lastError())
        }

        try applySessionOptions(sessionID: sessionID, settings: settings)
        return sessionID
    }

    func resetSession(_ sessionID: BRimeSessionId, schemaID: String, settings: RimeSettings) throws
        -> BRimeSessionId
    {
        _ = BRimeDestroySession(sessionID)
        return try makeSession(schemaID: schemaID, settings: settings)
    }

    func applySessionOptions(sessionID: BRimeSessionId, settings: RimeSettings) throws {
        let requiredOptions: [(String, Bool)] = [
            ("ascii_mode", false),
            ("full_shape", false),
            ("ascii_punct", false),
            ("zh_trad", settings.characterForm == .traditional),
        ]

        for (optionName, enabled) in requiredOptions {
            guard BRimeSetOption(sessionID, optionName, enabled) else {
                throw RimeError.setupFailed(Self.lastError())
            }
        }
    }

    func makeTokenizer(settings: RimeSettings) throws -> PinyinTokenizer {
        try prepare(settings: settings)
        guard let tokenizer else {
            throw RimeError.missingResource("luna_pinyin.dict.yaml")
        }
        return tokenizer
    }

    func makeLexicon(settings: RimeSettings) throws -> RimeLexicon {
        try prepare(settings: settings)
        guard let lexicon else {
            throw RimeError.missingResource("biline_phrases.dict.yaml")
        }
        return lexicon
    }

    private static func lastError() -> String {
        guard let cString = BRimeCopyLastError() else {
            return "unknown error"
        }
        defer { BRimeFreeCString(cString) }
        return String(cString: cString)
    }
}

private struct RimePaths {
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

    func prepareFilesystem(settings: RimeSettings) throws {
        let fileManager = FileManager.default

        if UserDefaults.standard.bool(forKey: RimeDefaults.smokeResetUserData),
            fileManager.fileExists(atPath: userDataDir.path)
        {
            try fileManager.removeItem(at: userDataDir)
            UserDefaults.standard.set(false, forKey: RimeDefaults.smokeResetUserData)
        }

        try fileManager.createDirectory(at: sharedDataDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: userDataDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)

        try copyBundledData()
        try writeCustomConfig(settings: settings)
    }

    private func copyBundledData() throws {
        let fileManager = FileManager.default
        let vendorDataDir = vendorDataRoot()
        let openCCSource = [
            Bundle.main.resourceURL?.appendingPathComponent("RimeRuntime/share/opencc"),
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Caches/BilineIME/RimeVendor/1.16.1/share/opencc"),
        ]
        .compactMap { $0 }
        .first { fileManager.fileExists(atPath: $0.path) }

        let vendorFiles = [
            RimeDataFile(
                relativePath: "luna_pinyin.dict.yaml",
                repoRelativePath: "rime-luna-pinyin/luna_pinyin.dict.yaml"),
            RimeDataFile(
                relativePath: "pinyin.yaml", repoRelativePath: "rime-luna-pinyin/pinyin.yaml"),
            RimeDataFile(relativePath: "essay.txt", repoRelativePath: "rime-essay/essay.txt"),
            RimeDataFile(
                relativePath: "rime_ice.dict.yaml", repoRelativePath: "rime-ice/rime_ice.dict.yaml"),
            RimeDataFile(
                relativePath: "cn_dicts/8105.dict.yaml",
                repoRelativePath: "rime-ice/cn_dicts/8105.dict.yaml"),
            RimeDataFile(
                relativePath: "cn_dicts/base.dict.yaml",
                repoRelativePath: "rime-ice/cn_dicts/base.dict.yaml"),
            RimeDataFile(
                relativePath: "cn_dicts/ext.dict.yaml",
                repoRelativePath: "rime-ice/cn_dicts/ext.dict.yaml"),
            RimeDataFile(
                relativePath: "cn_dicts/tencent.dict.yaml",
                repoRelativePath: "rime-ice/cn_dicts/tencent.dict.yaml"),
            RimeDataFile(
                relativePath: "cn_dicts/others.dict.yaml",
                repoRelativePath: "rime-ice/cn_dicts/others.dict.yaml"),
        ]

        for file in vendorFiles {
            guard
                let source = candidateSource(
                    appBundleRoot: vendorDataDir,
                    relativePath: file.relativePath,
                    vendorPath: repoVendorFile(relativePath: file.repoRelativePath)
                )
            else {
                throw RimeError.missingResource(file.relativePath)
            }
            try copyItem(
                at: source, to: sharedDataDir.appendingPathComponent(file.relativePath),
                using: fileManager)
        }

        for (resourceName, ext) in [
            ("default", "yaml"),
            ("biline_pinyin.schema", "yaml"),
            ("biline_pinyin.dict", "yaml"),
            ("biline_phrases.dict", "yaml"),
            ("biline_modern_phrases.dict", "yaml"),
        ] {
            let source =
                Bundle.module.url(
                    forResource: resourceName,
                    withExtension: ext,
                    subdirectory: "RimeTemplates"
                )
                ?? Bundle.module.url(
                    forResource: resourceName,
                    withExtension: ext
                )

            guard let source else {
                throw RimeError.missingResource("\(resourceName).\(ext)")
            }
            try copyItem(
                at: source,
                to: sharedDataDir.appendingPathComponent("\(resourceName).\(ext)"),
                using: fileManager
            )
        }

        if let openCCSource {
            let destination = sharedDataDir.appendingPathComponent("opencc", isDirectory: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: openCCSource, to: destination)
        }
    }

    private func writeCustomConfig(settings: RimeSettings) throws {
        let fuzzyPatches: [String] =
            settings.fuzzyPinyinEnabled
            ? [
                "      - pinyin:/zh_z_bufen",
                "      - pinyin:/n_l_bufen",
                "      - pinyin:/eng_ong_bufen",
                "      - pinyin:/en_eng_bufen",
            ]
            : []

        let lines =
            [
                "patch:",
                "  menu/page_size: \(max(1, settings.pageSize))",
                "  switches/@0/reset: \(settings.characterForm == .traditional ? 1 : 0)",
                "  zh_trad/option_name: zh_trad",
                "  speller/algebra:",
                "    __patch:",
                "      - pinyin:/abbreviation",
                "      - pinyin:/spelling_correction",
                "      - pinyin:/key_correction",
            ] + fuzzyPatches

        let contents = lines.joined(separator: "\n") + "\n"
        let url = userDataDir.appendingPathComponent("biline_pinyin.custom.yaml")
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func candidateSource(appBundleRoot: URL?, relativePath: String, vendorPath: URL) -> URL?
    {
        let fileManager = FileManager.default
        if let appBundleRoot {
            let candidate = appBundleRoot.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        if fileManager.fileExists(atPath: vendorPath.path) {
            return vendorPath
        }
        return nil
    }

    private func vendorDataRoot() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("RimeRuntime/rime-data")
    }

    private func repoVendorFile(relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Vendor")
            .appendingPathComponent(relativePath)
    }

    private func copyItem(at source: URL, to destination: URL, using fileManager: FileManager)
        throws
    {
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }
}

private struct RimeDataFile {
    let relativePath: String
    let repoRelativePath: String
}
