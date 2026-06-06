import XCTest
@testable import Ksign

final class OptionsMigrationTests: XCTestCase {
	func testMissingNewPropertiesUseDefaultsWithoutResettingSavedValues() throws {
		let encoded = try JSONEncoder().encode(Options.defaultOptions)
		var json = try XCTUnwrap(
			JSONSerialization.jsonObject(with: encoded) as? [String: Any]
		)
		json.removeValue(forKey: "removeSupportedDevices")
		json["ppqProtection"] = false

		let oldData = try JSONSerialization.data(withJSONObject: json)
		let migrated = try XCTUnwrap(OptionsManager.decodeOptionsMergingDefaults(oldData))

		XCTAssertTrue(migrated.removeSupportedDevices)
		XCTAssertFalse(migrated.ppqProtection)
	}
}
