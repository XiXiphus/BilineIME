import BilineSettings
import XCTest

@testable import BilineOperations

final class CredentialOperationsTests: XCTestCase {
    private struct MockRunner: CommandRunning {
        func run(_ executable: String, _ arguments: [String], allowFailure: Bool) throws
            -> CommandResult
        {
            CommandResult(status: 0, output: "", errorOutput: "")
        }

        func runShell(_ command: String, allowFailure: Bool) throws -> CommandResult {
            CommandResult(status: 0, output: "", errorOutput: "")
        }
    }

    func testStatusReportDoesNotRevealSecrets() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("alibaba-credentials.json")
        let operations = AlibabaCredentialOperations(
            domain: "test.biline.credentials.\(UUID().uuidString)",
            fileURL: fileURL,
            runner: MockRunner()
        )

        let report = operations.statusReport()

        XCTAssertTrue(report.contains("provider=<missing>"))
        XCTAssertTrue(report.contains("credential_file=missing"))
        XCTAssertFalse(report.contains("accessKeySecret="))
    }

    func testConfigureAndClearCredentialState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let operations = AlibabaCredentialOperations(
            domain: "test.biline.credentials.\(UUID().uuidString)",
            fileURL: directory.appendingPathComponent("alibaba-credentials.json"),
            runner: MockRunner()
        )
        let record = BilineAlibabaCredentialRecord(
            accessKeyId: "access-key-id",
            accessKeySecret: "access-key-secret",
            regionId: "cn-hangzhou",
            endpoint: "https://mt.cn-hangzhou.aliyuncs.com"
        )

        let configured = try operations.configure(record: record)

        XCTAssertTrue(configured.contains("provider=aliyun"))
        XCTAssertTrue(configured.contains("credential_file_accessKeyId=13"))
        XCTAssertTrue(configured.contains("credential_file_accessKeySecret=17"))
        XCTAssertFalse(configured.contains(record.accessKeySecret))

        let cleared = operations.clear()

        XCTAssertTrue(cleared.contains("credentials cleared"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: operations.store.fileURL.path))
        XCTAssertTrue(operations.statusReport().contains("provider=<missing>"))
    }
}
