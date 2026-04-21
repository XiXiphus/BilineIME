import XCTest
@testable import BilineSettings

final class AlibabaCredentialFileStoreTests: XCTestCase {
    func testSaveLoadAndStatusRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = BilineCredentialFileStore(
            fileURL: directory.appendingPathComponent("alibaba-credentials.json")
        )
        let record = BilineAlibabaCredentialRecord(
            accessKeyId: "test-access-key-id",
            accessKeySecret: "test-access-key-secret",
            regionId: "cn-hangzhou",
            endpoint: "https://mt.cn-hangzhou.aliyuncs.com"
        )

        try store.save(record)

        XCTAssertEqual(try store.load(), record)
        XCTAssertEqual(
            store.status(),
            BilineCredentialFileStatus(
                fileURL: store.fileURL,
                accessKeyIdLength: record.accessKeyId.count,
                accessKeySecretLength: record.accessKeySecret.count,
                loadError: nil
            )
        )
    }

    func testDefaultURLUsesInputMethodContainer() {
        let url = BilineAppPath.credentialFileURL(
            inputMethodBundleIdentifier: "io.github.xixiphus.inputmethod.BilineIME.dev"
        )

        XCTAssertTrue(url.path.contains("Library/Containers/io.github.xixiphus.inputmethod.BilineIME.dev"))
        XCTAssertEqual(url.lastPathComponent, "alibaba-credentials.json")
    }

    func testRuntimeURLUsesApplicationSupportDirectory() {
        let url = BilineAppPath.inputMethodRuntimeCredentialFileURL()

        XCTAssertTrue(url.path.contains("Library/Application Support/BilineIME"))
        XCTAssertEqual(url.lastPathComponent, "alibaba-credentials.json")
    }

    func testMissingFileStatusReportsMissingWithoutSecretData() {
        let store = BilineCredentialFileStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathComponent("alibaba-credentials.json")
        )

        XCTAssertEqual(
            store.status(),
            BilineCredentialFileStatus(
                fileURL: store.fileURL,
                accessKeyIdLength: nil,
                accessKeySecretLength: nil,
                loadError: .missing
            )
        )
    }
}
