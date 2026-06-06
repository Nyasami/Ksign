import XCTest
@testable import Ksign

final class ARArchiveTests: XCTestCase {
	func testRejectsTruncatedHeader() async throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: url) }

		var data = Data("!<arch>\n".utf8)
		data.append(Data(repeating: 0, count: 10))
		try data.write(to: url)

		do {
			let archive = try AR(with: url)
			_ = try await archive.extract()
			XCTFail("Expected the truncated archive to be rejected")
		} catch let error as ARError {
			XCTAssertEqual(error.errorDescription, "Invalid AR archive: Truncated file header")
		}
	}

	func testAllowsZeroLengthMember() async throws {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: url) }

		var data = Data("!<arch>\n".utf8)
		data.append(_field("empty/", length: 16))
		data.append(_field("0", length: 12))
		data.append(_field("0", length: 6))
		data.append(_field("0", length: 6))
		data.append(_field("0", length: 8))
		data.append(_field("0", length: 10))
		data.append(Data("`\n".utf8))
		try data.write(to: url)

		let archive = try AR(with: url)
		let files = try await archive.extract()

		XCTAssertEqual(files.count, 1)
		XCTAssertEqual(files.first?.name, "empty")
		XCTAssertEqual(files.first?.size, 0)
	}

	private func _field(_ value: String, length: Int) -> Data {
		let padded = value.padding(toLength: length, withPad: " ", startingAt: 0)
		return Data(padded.prefix(length).utf8)
	}
}
