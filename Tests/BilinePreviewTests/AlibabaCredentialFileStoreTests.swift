import XCTest
@testable import BilinePreview

final class AlibabaCredentialFileStoreTests: XCTestCase {
    func testSaveLoadAndStatusRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AlibabaCredentialFileStore(
            fileURL: directory.appendingPathComponent("alibaba-credentials.json")
        )
        let record = AlibabaCredentialFileRecord(
            accessKeyId: "test-access-key-id",
            accessKeySecret: "test-access-key-secret",
            regionId: "cn-hangzhou",
            endpoint: "https://mt.cn-hangzhou.aliyuncs.com"
        )

        try store.save(record)

        XCTAssertEqual(store.load(), record)
        XCTAssertEqual(
            store.status(),
            AlibabaCredentialFileStatus(
                accessKeyIdLength: record.accessKeyId.count,
                accessKeySecretLength: record.accessKeySecret.count
            )
        )
    }

    func testDefaultURLUsesInputMethodContainer() {
        let url = AlibabaCredentialFileStore.defaultURL(
            inputMethodBundleIdentifier: "io.github.xixiphus.inputmethod.BilineIME.dev"
        )

        XCTAssertTrue(url.path.contains("Library/Containers/io.github.xixiphus.inputmethod.BilineIME.dev"))
        XCTAssertEqual(url.lastPathComponent, "alibaba-credentials.json")
    }
}
