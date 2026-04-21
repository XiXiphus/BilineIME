import BilineCore
import Foundation

public enum TargetLanguage: String, Sendable, Codable, CaseIterable {
    case english = "en"
}

public protocol TranslationProvider: Sendable {
    var providerIdentifier: String { get }
    var providerModelIdentifier: String { get }
    var translationProfileIdentifier: String { get }
    func translate(_ text: String, target: TargetLanguage) async throws -> String
}

extension TranslationProvider {
    public var providerModelIdentifier: String { "default" }
    public var translationProfileIdentifier: String { "default" }
}

public protocol BatchTranslationProvider: TranslationProvider {
    func translateBatch(_ texts: [String], target: TargetLanguage) async throws -> [String: String]
}

public protocol SettingsStore: Sendable {
    var targetLanguage: TargetLanguage { get }
    var previewEnabled: Bool { get }
    var compactColumnCount: Int { get }
    var expandedRowCount: Int { get }
    var fuzzyPinyinEnabled: Bool { get }
    var characterForm: CharacterForm { get }
    var punctuationForm: PunctuationForm { get }
    var pageSize: Int { get }
}
