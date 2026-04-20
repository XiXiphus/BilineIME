import CryptoKit
import Foundation

public struct AlibabaMachineTranslationCredentials: Sendable, Equatable {
    public let accessKeyId: String
    public let accessKeySecret: String

    public init(accessKeyId: String, accessKeySecret: String) {
        self.accessKeyId = accessKeyId
        self.accessKeySecret = accessKeySecret
    }
}

public struct AlibabaMachineTranslationConfiguration: Sendable, Equatable {
    public let endpoint: URL
    public let regionId: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let formatType: String
    public let scene: String
    public let apiType: String
    public let maxItemsPerBatch: Int
    public let maxCharactersPerItem: Int

    public init(
        endpoint: URL = URL(string: "https://mt.cn-hangzhou.aliyuncs.com")!,
        regionId: String = "cn-hangzhou",
        sourceLanguage: String = "zh",
        targetLanguage: String = "en",
        formatType: String = "text",
        scene: String = "general",
        apiType: String = "translate_standard",
        maxItemsPerBatch: Int = 50,
        maxCharactersPerItem: Int = 1_000
    ) {
        self.endpoint = endpoint
        self.regionId = regionId
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.formatType = formatType
        self.scene = scene
        self.apiType = apiType
        self.maxItemsPerBatch = max(1, maxItemsPerBatch)
        self.maxCharactersPerItem = max(1, maxCharactersPerItem)
    }
}

public enum AlibabaMachineTranslationError: Error, Equatable, Sendable {
    case unsupportedTargetLanguage(TargetLanguage)
    case invalidEndpoint
    case emptyBatch
    case textTooLong(String)
    case requestEncodingFailed
    case invalidResponse
    case httpStatus(Int)
    case serviceError(code: String, message: String)
    case throttled(code: String, message: String)
    case authenticationFailed(code: String, message: String)
}

public struct AlibabaMachineTranslationHTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol AlibabaMachineTranslationTransport: Sendable {
    func send(_ request: URLRequest) async throws -> AlibabaMachineTranslationHTTPResponse
}

public struct URLSessionAlibabaMachineTranslationTransport: AlibabaMachineTranslationTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> AlibabaMachineTranslationHTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlibabaMachineTranslationError.invalidResponse
        }
        return AlibabaMachineTranslationHTTPResponse(
            statusCode: httpResponse.statusCode,
            data: data
        )
    }
}

public struct AlibabaOpenAPISignedRequest: Sendable, Equatable {
    public let authorization: String
    public let canonicalRequest: String
    public let stringToSign: String
    public let signedHeaders: String
    public let hashedPayload: String
}

public struct AlibabaOpenAPISigner: Sendable {
    public static let algorithm = "ACS3-HMAC-SHA256"

    public init() {}

    public func sign(
        method: String = "POST",
        canonicalURI: String = "/",
        queryItems: [URLQueryItem] = [],
        host: String,
        action: String,
        version: String,
        contentType: String,
        body: Data,
        credentials: AlibabaMachineTranslationCredentials,
        date: String,
        nonce: String
    ) -> AlibabaOpenAPISignedRequest {
        let hashedPayload = body.sha256HexDigest
        let headers = [
            "content-type": contentType,
            "host": host,
            "x-acs-action": action,
            "x-acs-content-sha256": hashedPayload,
            "x-acs-date": date,
            "x-acs-signature-nonce": nonce,
            "x-acs-version": version,
        ]
        let sortedHeaderKeys = headers.keys.sorted()
        let canonicalHeaders = sortedHeaderKeys
            .map { "\($0):\(headers[$0]!.trimmingCharacters(in: .whitespacesAndNewlines))\n" }
            .joined()
        let signedHeaders = sortedHeaderKeys.joined(separator: ";")
        let canonicalRequest = [
            method.uppercased(),
            canonicalURI,
            canonicalQueryString(queryItems),
            canonicalHeaders,
            signedHeaders,
            hashedPayload,
        ].joined(separator: "\n")
        let stringToSign = [
            Self.algorithm,
            Data(canonicalRequest.utf8).sha256HexDigest,
        ].joined(separator: "\n")
        let signature = hmacSHA256Hex(
            stringToSign,
            secret: credentials.accessKeySecret
        )
        let authorization =
            "\(Self.algorithm) Credential=\(credentials.accessKeyId),SignedHeaders=\(signedHeaders),Signature=\(signature)"
        return AlibabaOpenAPISignedRequest(
            authorization: authorization,
            canonicalRequest: canonicalRequest,
            stringToSign: stringToSign,
            signedHeaders: signedHeaders,
            hashedPayload: hashedPayload
        )
    }

    private func canonicalQueryString(_ queryItems: [URLQueryItem]) -> String {
        queryItems
            .sorted {
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return ($0.value ?? "") < ($1.value ?? "")
            }
            .map { item in
                "\(Self.percentEncode(item.name))=\(Self.percentEncode(item.value ?? ""))"
            }
            .joined(separator: "&")
    }

    public static func percentEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func hmacSHA256Hex(_ value: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(value.utf8),
            using: key
        )
        return Data(signature).hexString
    }
}

public actor AlibabaMachineTranslationProvider: BatchTranslationProvider {
    public nonisolated let providerIdentifier = "aliyun.machine-translation"
    public nonisolated let providerModelIdentifier = "GetBatchTranslate"
    public nonisolated let translationProfileIdentifier: String

    private let credentials: AlibabaMachineTranslationCredentials
    private let configuration: AlibabaMachineTranslationConfiguration
    private let transport: any AlibabaMachineTranslationTransport
    private let signer: AlibabaOpenAPISigner

    public init(
        credentials: AlibabaMachineTranslationCredentials,
        configuration: AlibabaMachineTranslationConfiguration = AlibabaMachineTranslationConfiguration(),
        transport: any AlibabaMachineTranslationTransport = URLSessionAlibabaMachineTranslationTransport(),
        signer: AlibabaOpenAPISigner = AlibabaOpenAPISigner()
    ) {
        self.credentials = credentials
        self.configuration = configuration
        self.transport = transport
        self.signer = signer
        self.translationProfileIdentifier =
            "region=\(configuration.regionId);scene=\(configuration.scene);apiType=\(configuration.apiType)"
    }

    public func translate(_ text: String, target: TargetLanguage) async throws -> String {
        let result = try await translateBatch([text], target: target)
        guard let translated = result[text] else {
            throw AlibabaMachineTranslationError.invalidResponse
        }
        return translated
    }

    public func translateBatch(
        _ texts: [String],
        target: TargetLanguage
    ) async throws -> [String: String] {
        guard target == .english else {
            throw AlibabaMachineTranslationError.unsupportedTargetLanguage(target)
        }

        let uniqueTexts = orderedUnique(texts).filter { !$0.isEmpty }
        guard !uniqueTexts.isEmpty else { throw AlibabaMachineTranslationError.emptyBatch }

        for text in uniqueTexts where text.count > configuration.maxCharactersPerItem {
            throw AlibabaMachineTranslationError.textTooLong(text)
        }

        var merged: [String: String] = [:]
        for chunk in uniqueTexts.chunked(into: configuration.maxItemsPerBatch) {
            let chunkResult = try await translateChunk(chunk)
            merged.merge(chunkResult) { current, _ in current }
        }
        return merged
    }

    public func makeRequest(
        texts: [String],
        date: String = AlibabaMachineTranslationProvider.currentACSDate(),
        nonce: String = UUID().uuidString
    ) throws -> URLRequest {
        guard let host = configuration.endpoint.host else {
            throw AlibabaMachineTranslationError.invalidEndpoint
        }
        let body = try formBody(for: texts)
        let contentType = "application/x-www-form-urlencoded"
        let signed = signer.sign(
            host: host,
            action: "GetBatchTranslate",
            version: "2018-10-12",
            contentType: contentType,
            body: body,
            credentials: credentials,
            date: date,
            nonce: nonce
        )

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(signed.authorization, forHTTPHeaderField: "Authorization")
        request.setValue("GetBatchTranslate", forHTTPHeaderField: "x-acs-action")
        request.setValue("2018-10-12", forHTTPHeaderField: "x-acs-version")
        request.setValue(signed.hashedPayload, forHTTPHeaderField: "x-acs-content-sha256")
        request.setValue(date, forHTTPHeaderField: "x-acs-date")
        request.setValue(nonce, forHTTPHeaderField: "x-acs-signature-nonce")
        return request
    }

    private func translateChunk(_ texts: [String]) async throws -> [String: String] {
        let request = try makeRequest(texts: texts)
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            if let serviceError = try? parseServiceError(response.data) {
                throw serviceError
            }
            throw AlibabaMachineTranslationError.httpStatus(response.statusCode)
        }
        return try parseResponse(response.data, sourceTexts: texts)
    }

    private func formBody(for texts: [String]) throws -> Data {
        let sourceText = try sourceTextPayload(for: texts)
        let fields = [
            "ApiType": configuration.apiType,
            "FormatType": configuration.formatType,
            "Scene": configuration.scene,
            "SourceLanguage": configuration.sourceLanguage,
            "SourceText": sourceText,
            "TargetLanguage": configuration.targetLanguage,
        ]
        let bodyString = fields
            .sorted { $0.key < $1.key }
            .map {
                "\(AlibabaOpenAPISigner.percentEncode($0.key))=\(AlibabaOpenAPISigner.percentEncode($0.value))"
            }
            .joined(separator: "&")
        return Data(bodyString.utf8)
    }

    private func sourceTextPayload(for texts: [String]) throws -> String {
        let keyed = Dictionary(uniqueKeysWithValues: texts.enumerated().map { index, text in
            (String(index), text)
        })
        guard JSONSerialization.isValidJSONObject(keyed),
            let data = try? JSONSerialization.data(
                withJSONObject: keyed,
                options: [.sortedKeys]
            ),
            let payload = String(data: data, encoding: .utf8)
        else {
            throw AlibabaMachineTranslationError.requestEncodingFailed
        }
        return payload
    }

    private func parseResponse(_ data: Data, sourceTexts: [String]) throws -> [String: String] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AlibabaMachineTranslationError.invalidResponse
        }

        if let code = root.codeValue, code != "200" {
            throw classifyServiceError(code: code, message: root.messageValue)
        }

        guard let translatedList = root["TranslatedList"] as? [[String: Any]] else {
            throw AlibabaMachineTranslationError.invalidResponse
        }

        var results: [String: String] = [:]
        for item in translatedList {
            guard item.codeValue == nil || item.codeValue == "200" else { continue }
            guard let index = item["index"] as? String,
                let translated = item["translated"] as? String,
                let sourceIndex = Int(index),
                sourceTexts.indices.contains(sourceIndex)
            else {
                continue
            }
            results[sourceTexts[sourceIndex]] = translated
        }
        return results
    }

    private func parseServiceError(_ data: Data) throws -> AlibabaMachineTranslationError {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = root.codeValue
        else {
            throw AlibabaMachineTranslationError.invalidResponse
        }
        return classifyServiceError(code: code, message: root.messageValue)
    }

    private func classifyServiceError(
        code: String,
        message: String?
    ) -> AlibabaMachineTranslationError {
        let resolvedMessage = message ?? "Alibaba Machine Translation error"
        if code.localizedCaseInsensitiveContains("Throttling")
            || code.localizedCaseInsensitiveContains("Limit")
        {
            return AlibabaMachineTranslationError.throttled(code: code, message: resolvedMessage)
        }
        if code.localizedCaseInsensitiveContains("Auth")
            || code.localizedCaseInsensitiveContains("Forbidden")
            || code.localizedCaseInsensitiveContains("AccessKey")
            || code == "403"
        {
            return AlibabaMachineTranslationError.authenticationFailed(code: code, message: resolvedMessage)
        }
        return AlibabaMachineTranslationError.serviceError(code: code, message: resolvedMessage)
    }

    private func orderedUnique(_ texts: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for text in texts where seen.insert(text).inserted {
            result.append(text)
        }
        return result
    }

    public static func currentACSDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
        ]
        return formatter.string(from: Date())
    }
}

private extension Data {
    var sha256HexDigest: String {
        Data(SHA256.hash(data: self)).hexString
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    var codeValue: String? {
        for key in ["Code", "code"] {
            if let string = self[key] as? String {
                return string
            }
            if let number = self[key] as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    var messageValue: String? {
        for key in ["Message", "message"] {
            if let string = self[key] as? String {
                return string
            }
        }
        return nil
    }
}
