import Foundation

extension RimePaths {
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

        try removeObsoleteSharedData(using: fileManager)
        try copyBundledData()
        try writeCustomConfig(settings: settings)
    }

    private func removeObsoleteSharedData(using fileManager: FileManager) throws {
        for relativePath in [
            "luna_pinyin.dict.yaml",
            "essay.txt",
            "biline_pinyin.schema.yaml",
            "cn_dicts/41448.dict.yaml",
        ] {
            let url = sharedDataDir.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
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
                relativePath: "pinyin.yaml", repoRelativePath: "rime-luna-pinyin/pinyin.yaml"),
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
            ("biline_pinyin_simp.schema", "yaml"),
            ("biline_pinyin_trad.schema", "yaml"),
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
                "  speller/algebra:",
                "    __patch:",
                "      - pinyin:/abbreviation",
                "      - pinyin:/spelling_correction",
                "      - pinyin:/key_correction",
            ] + fuzzyPatches

        let contents = lines.joined(separator: "\n") + "\n"
        let url = userDataDir.appendingPathComponent("\(settings.schemaID).custom.yaml")
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
