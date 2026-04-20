import BilinePreview
import Foundation
import XCTest

final class AlibabaMachineTranslationProviderTests: XCTestCase {
    func testRequestBodyUsesBatchTranslateFormDataAndStableSourceIDs() async throws {
        let transport = StubAlibabaTransport(
            response: successResponse([
                ("0", "hello"),
                ("1", "good apple"),
            ])
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )

        let request = try await provider.makeRequest(
            texts: ["你好", "好苹果"],
            date: "2026-04-20T01:00:00Z",
            nonce: "nonce"
        )
        let body = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        let fields = formFields(body)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://mt.cn-hangzhou.aliyuncs.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-acs-action"), "GetBatchTranslate")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-acs-version"), "2018-10-12")
        XCTAssertEqual(fields["ApiType"], "translate_standard")
        XCTAssertEqual(fields["FormatType"], "text")
        XCTAssertEqual(fields["Scene"], "general")
        XCTAssertEqual(fields["SourceLanguage"], "zh")
        XCTAssertEqual(fields["TargetLanguage"], "en")

        let sourceText = try XCTUnwrap(fields["SourceText"])
        let sourceMap = try decodeSourceText(sourceText)
        XCTAssertEqual(sourceMap, ["0": "你好", "1": "好苹果"])
    }

    func testTranslateBatchMapsSuccessfulItemsBySourceText() async throws {
        let transport = StubAlibabaTransport(
            response: successResponse([
                ("0", "hello"),
                ("1", "good apple"),
            ])
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )

        let result = try await provider.translateBatch(["你好", "好苹果"], target: .english)

        XCTAssertEqual(result["你好"], "hello")
        XCTAssertEqual(result["好苹果"], "good apple")
        let requestCount = await transport.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testTranslateBatchChunksLargeRequestsAtFiftyItems() async throws {
        let transport = StubAlibabaTransport(
            responses: [
                successResponse((0..<50).map { (String($0), "t\($0)") }),
                successResponse((0..<5).map { (String($0), "u\($0)") }),
            ]
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )
        let texts = (0..<55).map { "候选\($0)" }

        let result = try await provider.translateBatch(texts, target: .english)

        XCTAssertEqual(result["候选0"], "t0")
        XCTAssertEqual(result["候选50"], "u0")
        let requestCount = await transport.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func testSingleItemFailureIsOmittedFromBatchResults() async throws {
        let transport = StubAlibabaTransport(
            response: jsonResponse(
                """
                {
                  "Code": 200,
                  "Message": "success",
                  "TranslatedList": [
                    {"code": "500", "index": "0", "translated": ""},
                    {"code": "200", "index": "1", "translated": "good apple"}
                  ]
                }
                """
            )
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )

        let result = try await provider.translateBatch(["你好", "好苹果"], target: .english)

        XCTAssertNil(result["你好"])
        XCTAssertEqual(result["好苹果"], "good apple")
    }

    func testThrottlingErrorIsClassified() async {
        let transport = StubAlibabaTransport(
            response: jsonResponse(
                """
                {"Code":"Throttling.User","Message":"QPS limit reached"}
                """
            )
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )

        do {
            _ = try await provider.translateBatch(["你好"], target: .english)
            XCTFail("Expected throttling error.")
        } catch AlibabaMachineTranslationError.throttled(let code, let message) {
            XCTAssertEqual(code, "Throttling.User")
            XCTAssertEqual(message, "QPS limit reached")
        } catch {
            XCTFail("Expected throttled, got \(error).")
        }
    }

    func testAuthenticationErrorIsClassified() async {
        let transport = StubAlibabaTransport(
            response: jsonResponse(
                """
                {"Code":"InvalidAccessKeyId.NotFound","Message":"invalid key"}
                """
            )
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )

        do {
            _ = try await provider.translateBatch(["你好"], target: .english)
            XCTFail("Expected auth error.")
        } catch AlibabaMachineTranslationError.authenticationFailed(let code, let message) {
            XCTAssertEqual(code, "InvalidAccessKeyId.NotFound")
            XCTAssertEqual(message, "invalid key")
        } catch {
            XCTFail("Expected authenticationFailed, got \(error).")
        }
    }

    func testHTTPStatusIsClassified() async {
        let transport = StubAlibabaTransport(
            response: AlibabaMachineTranslationHTTPResponse(
                statusCode: 500,
                data: Data("{}".utf8)
            )
        )
        let provider = AlibabaMachineTranslationProvider(
            credentials: credentials,
            transport: transport
        )

        do {
            _ = try await provider.translateBatch(["你好"], target: .english)
            XCTFail("Expected HTTP status error.")
        } catch AlibabaMachineTranslationError.httpStatus(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Expected httpStatus, got \(error).")
        }
    }
}

final class AlibabaMachineTranslationLiveTests: XCTestCase {
    func testLiveBatchTranslationWhenCredentialsAreAvailable() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let accessKeyId = environment["ALIBABA_CLOUD_ACCESS_KEY_ID"],
            let accessKeySecret = environment["ALIBABA_CLOUD_ACCESS_KEY_SECRET"],
            !accessKeyId.isEmpty,
            !accessKeySecret.isEmpty
        else {
            throw XCTSkip("Set ALIBABA_CLOUD_ACCESS_KEY_ID and ALIBABA_CLOUD_ACCESS_KEY_SECRET to run live Alibaba translation tests.")
        }

        let provider = AlibabaMachineTranslationProvider(
            credentials: AlibabaMachineTranslationCredentials(
                accessKeyId: accessKeyId,
                accessKeySecret: accessKeySecret
            )
        )
        let result = try await provider.translateBatch(["你好", "好苹果", "输入法"], target: .english)

        XCTAssertFalse(result["你好", default: ""].isEmpty)
        XCTAssertFalse(result["好苹果", default: ""].isEmpty)
        XCTAssertFalse(result["输入法", default: ""].isEmpty)
    }
}

private let credentials = AlibabaMachineTranslationCredentials(
    accessKeyId: "testid",
    accessKeySecret: "testsecret"
)

private actor StubAlibabaTransport: AlibabaMachineTranslationTransport {
    private var responses: [AlibabaMachineTranslationHTTPResponse]
    private var requests: [URLRequest] = []

    init(response: AlibabaMachineTranslationHTTPResponse) {
        self.responses = [response]
    }

    init(responses: [AlibabaMachineTranslationHTTPResponse]) {
        self.responses = responses
    }

    var requestCount: Int {
        requests.count
    }

    func send(_ request: URLRequest) async throws -> AlibabaMachineTranslationHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            return jsonResponse("{}")
        }
        return responses.removeFirst()
    }
}

private func successResponse(_ translations: [(String, String)]) -> AlibabaMachineTranslationHTTPResponse {
    let items = translations
        .map { #"{"code":"200","index":"\#($0.0)","translated":"\#($0.1)"}"# }
        .joined(separator: ",")
    return jsonResponse(
        """
        {"Code":200,"Message":"success","TranslatedList":[\(items)]}
        """
    )
}

private func jsonResponse(_ json: String) -> AlibabaMachineTranslationHTTPResponse {
    AlibabaMachineTranslationHTTPResponse(
        statusCode: 200,
        data: Data(json.utf8)
    )
}

private func formFields(_ body: String) -> [String: String] {
    Dictionary(
        uniqueKeysWithValues: body.split(separator: "&").compactMap { item in
            let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return (
                parts[0].removingPercentEncoding ?? parts[0],
                parts[1].removingPercentEncoding ?? parts[1]
            )
        }
    )
}

private func decodeSourceText(_ sourceText: String) throws -> [String: String] {
    let data = try XCTUnwrap(sourceText.data(using: .utf8))
    return try XCTUnwrap(
        JSONSerialization.jsonObject(with: data) as? [String: String]
    )
}
