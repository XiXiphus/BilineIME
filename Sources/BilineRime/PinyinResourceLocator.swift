import Foundation

enum PinyinResourceLocator {
    struct ResourceURLs {
        let tokenizerSeed: URL
        let lexiconFiles: [URL]
    }

    static func dictionaryURLs() throws -> ResourceURLs {
        let candidates = [
            repoVendorFile("rime-luna-pinyin/luna_pinyin.dict.yaml"),
            bundleResource("luna_pinyin.dict", ext: "yaml", subdirectory: nil),
            bundleResource("luna_pinyin.dict", ext: "yaml", subdirectory: "RimeTemplates"),
        ].compactMap { $0 }

        guard
            let tokenizerSeed = candidates.first(where: {
                FileManager.default.fileExists(atPath: $0.path)
            })
        else {
            throw RimeError.missingResource("luna_pinyin.dict.yaml")
        }

        let lexiconFiles = [
            tokenizerSeed,
            bundleResource("biline_phrases.dict", ext: "yaml", subdirectory: "RimeTemplates"),
            bundleResource(
                "biline_modern_phrases.dict", ext: "yaml", subdirectory: "RimeTemplates"),
            repoResource("Sources/BilineRime/Resources/RimeTemplates/biline_phrases.dict.yaml"),
            repoResource(
                "Sources/BilineRime/Resources/RimeTemplates/biline_modern_phrases.dict.yaml"),
        ].compactMap { $0 }.filter { FileManager.default.fileExists(atPath: $0.path) }

        return ResourceURLs(tokenizerSeed: tokenizerSeed, lexiconFiles: lexiconFiles)
    }

    private static func bundleResource(_ name: String, ext: String, subdirectory: String?) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
            ?? Bundle.module.url(forResource: name, withExtension: ext)
    }

    private static func repoResource(_ relativePath: String) -> URL? {
        let url = repoRoot().appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func repoVendorFile(_ relativePath: String) -> URL? {
        repoResource("Vendor/\(relativePath)")
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
