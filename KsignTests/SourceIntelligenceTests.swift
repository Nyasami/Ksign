import XCTest
@testable import Ksign

final class SourceIntelligenceTests: XCTestCase {
	func testOnlyNewerSourceVersionIsAnUpdate() {
		XCTAssertTrue(
			SourceIntelligenceManager.isNewerVersion("2.0", than: ["1.9"])
		)
		XCTAssertFalse(
			SourceIntelligenceManager.isNewerVersion("1.9", than: ["2.0"])
		)
		XCTAssertFalse(
			SourceIntelligenceManager.isNewerVersion("2.0", than: ["1.0", "2.0"])
		)
	}
}
