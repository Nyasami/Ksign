import Foundation

enum CertificateSelection {
	static let uuidKey = "feather.selectedCertUUID"
	private static let legacyIndexKey = "feather.selectedCert"

	static func selected(in certificates: [CertificatePair], uuid: String) -> CertificatePair? {
		if let selected = certificates.first(where: { $0.uuid == uuid }) {
			return selected
		}

		let legacyIndex = UserDefaults.standard.integer(forKey: legacyIndexKey)
		if certificates.indices.contains(legacyIndex) {
			let selected = certificates[legacyIndex]
			UserDefaults.standard.set(selected.uuid, forKey: uuidKey)
			UserDefaults.standard.removeObject(forKey: legacyIndexKey)
			return selected
		}

		guard let first = certificates.first else { return nil }
		UserDefaults.standard.set(first.uuid, forKey: uuidKey)
		return first
	}

	static func clear() {
		UserDefaults.standard.removeObject(forKey: uuidKey)
		UserDefaults.standard.removeObject(forKey: legacyIndexKey)
	}
}
