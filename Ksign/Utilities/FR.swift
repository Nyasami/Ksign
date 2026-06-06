//
//  FR.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Foundation.NSURL
import UIKit.UIImage
import Zsign
import NimbleJSON
import AltSourceKit
import IDeviceSwift

enum FR {
	static func handlePackageFile(
		_ ipa: URL,
		download: Download? = nil,
		completion: @escaping (Error?) -> Void
	) {
		let jobID = download?.jobID ?? JobsManager.shared.start(
			kind: .importApp,
			title: ipa.lastPathComponent,
			detail: .localized("Preparing import"),
			sourceURL: ipa
		)
		Task.detached {
			let handler = AppFileHandler(file: ipa, download: download)
			
			do {
				try await handler.copy()
				JobsManager.shared.update(jobID, progress: 0.1, detail: .localized("Extracting"))
				try await handler.extract()
				JobsManager.shared.update(jobID, progress: 0.85, detail: .localized("Saving to Library"))
				try await handler.move()
				try await handler.addToDatabase()
                
                                try? await handler.clean()
				if download == nil {
					JobsManager.shared.complete(jobID, detail: .localized("Imported to Library"))
				}
				await MainActor.run {
					completion(nil)
				}
			} catch {
				try await handler.clean()
				if download == nil {
					JobsManager.shared.fail(jobID, error: error, detail: .localized("Import failed"))
				}
				await MainActor.run {
					completion(error)
				}
			}
		}
	}
	
	static func signPackageFile(
		_ app: AppInfoPresentable,
		using options: Options,
		icon: UIImage?,
		certificate: CertificatePair?,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
			do {
				try await signPackageFile(
					app,
					using: options,
					icon: icon,
					certificate: certificate
				)
				await MainActor.run {
					completion(nil)
				}
			} catch {
				await MainActor.run {
					completion(error)
				}
			}
		}
	}

	static func signPackageFile(
		_ app: AppInfoPresentable,
		using options: Options,
		icon: UIImage?,
		certificate: CertificatePair?
	) async throws {
		let appName = await MainActor.run {
			app.name ?? String.localized("Unknown App")
		}
		let jobID = JobsManager.shared.start(
			kind: .signing,
			title: appName,
			detail: .localized("Preparing")
		)
		let handler = SigningHandler(app: app, options: options)
		if !options.onlyModify {
			handler.appCertificate = certificate
		}
		handler.appIcon = icon

		do {
			try await handler.copy()
			JobsManager.shared.update(jobID, progress: 0.15, detail: .localized("Modifying and signing"))
			try await handler.modify()
			try? await handler.clean()
			JobsManager.shared.complete(jobID, detail: .localized("Signing completed"))
		} catch {
			try? await handler.clean()
			JobsManager.shared.fail(jobID, error: error, detail: .localized("Signing failed"))
			throw error
		}
	}
	
	static func handleCertificateFiles(
		p12URL: URL,
		provisionURL: URL,
		p12Password: String,
		certificateName: String,
		completion: @escaping (Error?) -> Void
	) {
		let jobID = JobsManager.shared.start(
			kind: .certificateImport,
			title: certificateName.isEmpty ? p12URL.lastPathComponent : certificateName,
			detail: .localized("Importing certificate")
		)
		Task.detached {
			let handler = CertificateFileHandler(
				key: p12URL,
				provision: provisionURL,
				password: p12Password,
				nickname: certificateName.isEmpty ? nil : certificateName
			)
			
			do {
				try await handler.copy()
				JobsManager.shared.update(jobID, progress: 0.7, detail: .localized("Saving certificate"))
				try await handler.addToDatabase()
				JobsManager.shared.complete(jobID, detail: .localized("Certificate imported"))
				await MainActor.run {
					completion(nil)
				}
			} catch {
				JobsManager.shared.fail(jobID, error: error, detail: .localized("Certificate import failed"))
				await MainActor.run {
					completion(error)
				}
			}
		}
	}
	
	
	static func checkPasswordForCertificate(
		for key: URL,
		with password: String,
		using provision: URL
	) -> Bool {
		defer {
			password_check_fix_WHAT_THE_FUCK_free(provision.path)
		}
		
		password_check_fix_WHAT_THE_FUCK(provision.path)
		
		if (!p12_password_check(key.path, password)) {
			return false
		}
		
		return true
	}
	
	static func checkPasswordForCertificateData(
		p12Data: Data,
		provisionData: Data,
		password: String
	) -> Bool {
		let tempDir = FileManager.default.temporaryDirectory
		let tempP12 = tempDir.appendingPathComponent("temp_cert.p12")
		let tempProvision = tempDir.appendingPathComponent("temp_provision.mobileprovision")
		
		defer {
			try? FileManager.default.removeItem(at: tempP12)
			try? FileManager.default.removeItem(at: tempProvision)
		}
		
		do {
			try p12Data.write(to: tempP12)
			try provisionData.write(to: tempProvision)
			
			return checkPasswordForCertificate(for: tempP12, with: password, using: tempProvision)
		} catch {
			print("Error creating temporary files for password check: \(error)")
			return false
		}
	}
	
	static func movePairing(_ url: URL) {
		let fileManager = FileManager.default
		let dest = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")

		try? fileManager.removeFileIfNeeded(at: dest)
		
		try? fileManager.copyItem(at: url, to: dest)
		
		HeartbeatManager.shared.start(true)
	}
	
	#if SERVER
	static func downloadSSLCertificates(
		from urlString: String,
		completion: @escaping (Bool) -> Void
	) {
		let generator = UINotificationFeedbackGenerator()
		generator.prepare()
		
		NBFetchService().fetch(from: urlString) { (result: Result<ServerPackModel, Error>) in
			switch result {
			case .success(let pack):
				do {
					let serverDir = URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Server")
					let pemURL = serverDir.appendingPathComponent("server.pem")
					let crtURL = serverDir.appendingPathComponent("server.crt")
					let commonNameURL = serverDir.appendingPathComponent("commonName.txt")
					
					try FileManager.default.createDirectoryIfNeeded(at: serverDir)
					try pack.key.write(to: pemURL, atomically: true, encoding: .utf8)
					try pack.cert.write(to: crtURL, atomically: true, encoding: .utf8)
					try pack.info.domains.commonName.write(to: commonNameURL, atomically: true, encoding: .utf8)
					
					generator.notificationOccurred(.success)
					completion(true)
				} catch {
					completion(false)
				}
			case .failure(_):
				completion(false)
			}
		}
	}
	#endif
	
	static func handleSource(
		_ urlString: String,
		isBuiltIn: Bool = false,
		completion: @escaping (Bool) -> Void
	) {
		guard let url = URL(string: urlString) else {
			completion(false)
			return
		}
		
		NBFetchService().fetch<ASRepository>(from: url) { (result: Result<ASRepository, Error>) in
			switch result {
			case .success(let data):
				let id = data.id ?? url.absoluteString
				
				if !Storage.shared.sourceExists(id) {
					Storage.shared.addSource(url, repository: data, id: id, isBuiltIn: isBuiltIn) { error in
						completion(error == nil)
					}
				} else {
					if !isBuiltIn {
						DispatchQueue.main.async {
							UIAlertController.showAlertWithOk(title: "Error", message: "Repository already added.")
						}
					}
					completion(isBuiltIn)
				}
			case .failure(let error):
				if !isBuiltIn {
					DispatchQueue.main.async {
						UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
					}
				}
				completion(false)
			}
		}
	}
}

private enum CertificateHandlerError: Error {
	case invalidCertificate
}
