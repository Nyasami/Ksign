import Foundation
import Security

enum CertificatePasswordStore {
	private static var service: String {
		"\(Bundle.main.bundleIdentifier ?? "Ksign").certificate-password"
	}

	static func password(for uuid: String) -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: uuid,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]

		var result: CFTypeRef?
		guard
			SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			let data = result as? Data
		else {
			return nil
		}
		return String(data: data, encoding: .utf8)
	}

	@discardableResult
	static func setPassword(_ password: String, for uuid: String) -> Bool {
		guard let data = password.data(using: .utf8) else { return false }

		let query = _baseQuery(for: uuid)
		let attributes: [String: Any] = [
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
			kSecValueData as String: data
		]
		let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
		guard updateStatus == errSecItemNotFound else {
			if updateStatus != errSecSuccess {
				print("Unable to update certificate password in Keychain: \(updateStatus)")
			}
			return updateStatus == errSecSuccess
		}

		let newItem: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: uuid,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
			kSecValueData as String: data
		]
		let addStatus = SecItemAdd(newItem as CFDictionary, nil)
		if addStatus != errSecSuccess {
			print("Unable to add certificate password to Keychain: \(addStatus)")
		}
		return addStatus == errSecSuccess
	}

	static func deletePassword(for uuid: String) {
		let status = SecItemDelete(_baseQuery(for: uuid) as CFDictionary)
		if status != errSecSuccess, status != errSecItemNotFound {
			print("Unable to delete certificate password from Keychain: \(status)")
		}
	}

	private static func _baseQuery(for uuid: String) -> [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: uuid
		]
	}
}
