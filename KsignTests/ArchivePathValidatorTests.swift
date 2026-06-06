import XCTest
@testable import Ksign

final class ArchivePathValidatorTests: XCTestCase {
	func testAllowsNestedPathInsideDestination() throws {
		let base = URL(fileURLWithPath: "/tmp/KsignArchiveTest", isDirectory: true)
		let destination = try ArchivePathValidator.destinationURL(
			base: base,
			entryPath: "Payload/Test.app/Info.plist"
		)

		XCTAssertTrue(destination.path.hasPrefix(base.path))
	}

	func testRejectsParentTraversal() {
		let base = URL(fileURLWithPath: "/tmp/KsignArchiveTest", isDirectory: true)

		XCTAssertThrowsError(
			try ArchivePathValidator.destinationURL(base: base, entryPath: "../../outside")
		)
	}

	func testRejectsAbsolutePath() {
		let base = URL(fileURLWithPath: "/tmp/KsignArchiveTest", isDirectory: true)

		XCTAssertThrowsError(
			try ArchivePathValidator.destinationURL(base: base, entryPath: "/private/outside")
		)
	}

	func testRejectsBackslashTraversal() {
		let base = URL(fileURLWithPath: "/tmp/KsignArchiveTest", isDirectory: true)

		XCTAssertThrowsError(
			try ArchivePathValidator.destinationURL(base: base, entryPath: #"Payload\..\..\outside"#)
		)
	}
}
