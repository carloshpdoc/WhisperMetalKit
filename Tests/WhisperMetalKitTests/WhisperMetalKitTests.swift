import XCTest
@testable import WhisperMetalKit

final class WhisperMetalKitTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(WhisperMetalKit.version.isEmpty)
    }
}
