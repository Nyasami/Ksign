//
//  Storage+Certificate.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator
import ZsignSwift

// MARK: - Class extension: certificate
extension Storage {
	func addCertificate(
		uuid: String,
		password: String? = nil,
		nickname: String? = nil,
		ppq: Bool = false,
		expiration: Date,
		completion: @escaping (Error?) -> Void
	) {
		context.perform {
			if let password, !CertificatePasswordStore.setPassword(password, for: uuid) {
				completion(CertificateStorageError.passwordStoreFailed)
				return
			}

			let new = CertificatePair(context: self.context)
			new.uuid = uuid
			new.date = Date()
			new.password = nil
			new.ppQCheck = ppq
			new.expiration = expiration
			new.nickname = nickname

			do {
				try self.context.save()
				UIImpactFeedbackGenerator(style: .light).impactOccurred()
				completion(nil)
			} catch {
				CertificatePasswordStore.deletePassword(for: uuid)
				self.context.delete(new)
				completion(error)
			}
		}
	}
    
    func revokagedCertificate(for cert: CertificatePair) {
        guard !cert.revoked else { return }
		print("Checking revokage for \(cert.nickname ?? "Unknown")")
        Zsign.checkRevokage(
            provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
            p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
            p12Password: password(for: cert)
        ) { (status, _, _) in
            if status == 1 {
                DispatchQueue.main.async {
                    cert.revoked = true
                    Storage.shared.saveContext()
                }
            }
        }
    }
    
    func getProvisionFileDecoded(for cert: CertificatePair) -> Certificate? {
        guard let url = getFile(.provision, from: cert) else {
            return nil
        }
        
        let read = CertificateReader(url)
        return read.decoded
    }
    
	func deleteCertificate(for cert: CertificatePair) {
		do {
			if let uuid = cert.uuid {
				CertificatePasswordStore.deletePassword(for: uuid)
			}
			if cert.p12Data == nil && cert.provisionData == nil {
				if let url = getUuidDirectory(for: cert) {
					try FileManager.default.removeItem(at: url)
				}
			}
			context.delete(cert)
			saveContext()
		} catch {
			print(error)
		}
	}

	func password(for cert: CertificatePair) -> String {
		var uuid: String?
		var legacyPassword: String?
		context.performAndWait {
			uuid = cert.uuid
			legacyPassword = cert.password
		}

		guard let uuid else { return legacyPassword ?? "" }
		if let password = CertificatePasswordStore.password(for: uuid) {
			return password
		}

		guard let legacyPassword else { return "" }
		if CertificatePasswordStore.setPassword(legacyPassword, for: uuid) {
			context.perform {
				cert.password = nil
				do {
					try self.context.save()
				} catch {
					print("Unable to remove legacy certificate password: \(error.localizedDescription)")
				}
			}
		}
		return legacyPassword
	}
		
	enum FileRequest: String {
		case certificate = "p12"
		case provision = "mobileprovision"
	}
	
	func getFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
		guard let url = getUuidDirectory(for: cert) else {
			return nil
		}
		
		return FileManager.default.getPath(in: url, for: type.rawValue)
	}
	
	func getUuidDirectory(for cert: CertificatePair) -> URL? {
		var uuid: String?
		context.performAndWait {
			uuid = cert.uuid
		}

		guard let uuid else { return nil }
		return FileManager.default.certificates(uuid)
	}
}

private enum CertificateStorageError: LocalizedError {
	case passwordStoreFailed

	var errorDescription: String? {
		"Unable to securely store the certificate password."
	}
}
