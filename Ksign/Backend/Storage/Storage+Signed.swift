//
//  Storage+Signed.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator

// MARK: - Class extension: Signed Apps
extension Storage {
	func addSigned(
		uuid: String,
		source: URL? = nil,
		certificate: CertificatePair? = nil,
		
		appName: String? = nil,
		appIdentifier: String? = nil,
		appVersion: String? = nil,
		appIcon: String? = nil,
		
		completion: @escaping (Error?) -> Void
	) {
		context.perform {
			let new = Signed(context: self.context)

			new.uuid = uuid
			new.source = source
			new.date = Date()
			// If nil, the app is ad-hoc signed or its certificate was deleted.
			new.certificate = certificate
			new.identifier = appIdentifier
			new.name = appName
			new.icon = appIcon
			new.version = appVersion

			do {
				try self.context.save()
				SourceIntelligenceManager.shared.invalidateLocalVersionSnapshot()
				UIImpactFeedbackGenerator(style: .light).impactOccurred()
				completion(nil)
			} catch {
				self.context.delete(new)
				completion(error)
			}
		}
	}
}
