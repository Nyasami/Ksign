//
//  Storage+Shared.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import CoreData

// MARK: - Class extension: Apps (Shared)
extension Storage {
	func getUuidDirectory(for app: AppInfoPresentable) -> URL? {
		var uuid: String?
		if let object = app as? NSManagedObject, let managedObjectContext = object.managedObjectContext {
			managedObjectContext.performAndWait {
				uuid = app.uuid
			}
		} else {
			uuid = app.uuid
		}

		guard let uuid else { return nil }
		return app is Signed
		? FileManager.default.signed(uuid)
		: FileManager.default.unsigned(uuid)
	}
	
	func getAppDirectory(for app: AppInfoPresentable) -> URL? {
		guard let url = getUuidDirectory(for: app) else { return nil }
		return FileManager.default.getPath(in: url, for: "app")
	}
	
	func deleteApp(for app: AppInfoPresentable) {
		if let url = getUuidDirectory(for: app) {
			try? FileManager.default.removeItem(at: url)
		}
		if let object = app as? NSManagedObject {
			context.perform {
				self.context.delete(object)
				do {
					try self.context.save()
					SourceIntelligenceManager.shared.invalidateLocalVersionSnapshot()
				} catch {
					print("Unable to delete app: \(error.localizedDescription)")
				}
			}
		}
	}
	
	func getCertificate(from app: AppInfoPresentable) -> CertificatePair? {
		guard let signed = app as? Signed, let managedObjectContext = signed.managedObjectContext else {
			return nil
		}
		var certificate: CertificatePair?
		managedObjectContext.performAndWait {
			certificate = signed.certificate
		}
		return certificate
	}
}

// MARK: - Helpers
struct AnyApp: Identifiable {
	let base: AppInfoPresentable
	var archive: Bool = false
	var signAndInstall: Bool = false
	
	var id: String {
		base.uuid ?? UUID().uuidString
	}
}

protocol AppInfoPresentable {
	var name: String? { get }
	var version: String? { get }
	var identifier: String? { get }
	var date: Date? { get }
	var icon: String? { get }
	var uuid: String? { get }
	var isSigned: Bool { get }
	
}

extension Signed: AppInfoPresentable {
	var isSigned: Bool { true }
}

extension Imported: AppInfoPresentable {
	var isSigned: Bool { false }
}
