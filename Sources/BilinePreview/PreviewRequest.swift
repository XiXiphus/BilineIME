import Foundation

public struct PreviewRequestKey: Sendable, Equatable, Hashable {
    public let sourceText: String
    public let sourceLanguage: String
    public let targetLanguage: TargetLanguage
    public let providerIdentifier: String
    public let providerModelIdentifier: String
    public let translationProfileIdentifier: String

    public init(
        sourceText: String,
        sourceLanguage: String = "zh",
        targetLanguage: TargetLanguage,
        providerIdentifier: String,
        providerModelIdentifier: String = "default",
        translationProfileIdentifier: String = "default"
    ) {
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.providerIdentifier = providerIdentifier
        self.providerModelIdentifier = providerModelIdentifier
        self.translationProfileIdentifier = translationProfileIdentifier
    }
}

public enum PreviewRequestPriority: Int, Sendable, Comparable {
    case prefetch = 0
    case visible = 1
    case selected = 2

    public static func < (lhs: PreviewRequestPriority, rhs: PreviewRequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TranslationPreviewSubscriberID: Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum PreviewState: Sendable, Equatable {
    case idle
    case loading(PreviewRequestKey, Int)
    case ready(PreviewRequestKey, String)
    case failed(PreviewRequestKey)
}
