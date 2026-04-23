import BilineOperations
import XCTest

final class ProcessRunnerTests: XCTestCase {
    func testProcessRunnerDrainsLargeOutputBeforeWaitingForExit() throws {
        let result = try ProcessCommandRunner().runShell(
            "yes 0123456789 | head -n 10000",
            allowFailure: false
        )

        XCTAssertEqual(result.status, 0)
        XCTAssertGreaterThan(result.output.count, 100_000)
        XCTAssertEqual(result.errorOutput, "")
    }
}
