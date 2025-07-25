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
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = CertificatePair(context: context)
		new.uuid = uuid
		new.date = Date()
		new.password = password
		new.ppQCheck = ppq
		new.expiration = expiration
		new.nickname = nickname
		
        saveContext()
        generator.impactOccurred()
        completion(nil)
	}
    
    func revokagedCertificate(for cert: CertificatePair) {
        guard !cert.revoked else { return }
		print("Checking revokage for \(cert.nickname ?? "Unknown")")
        Zsign.checkRevokage(
            provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
            p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
            p12Password: cert.password ?? ""
        ) { (status, _, _) in
            if status == 1 {
                DispatchQueue.main.async {
                    cert.revoked = true
                    Storage.shared.saveContext()
                }
            }
        }
    }
    
	func addCertificateWithData(
		uuid: String,
		p12Data: Data,
		provisionData: Data,
		password: String? = nil,
		nickname: String? = nil,
		ppq: Bool = false,
		expiration: Date,
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = CertificatePair(context: context)
		new.uuid = uuid
		new.date = Date()
		new.password = password
		new.ppQCheck = ppq
		new.expiration = expiration
		new.nickname = nickname
		
		new.p12Data = CertificateEncryption.safeEncrypt(p12Data)
		new.provisionData = CertificateEncryption.safeEncrypt(provisionData)
		
        saveContext()
        generator.impactOccurred()
        completion(nil)
	}
	
	func deleteCertificate(for cert: CertificatePair) {
		do {
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
		
	enum FileRequest: String {
		case certificate = "p12"
		case provision = "mobileprovision"
	}
	
	func getFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
	
		if hasInMemoryData(for: cert) {
			return getTemporaryFile(type, from: cert)
		}
		
		guard let url = getUuidDirectory(for: cert) else {
			return nil
		}
		
		return FileManager.default.getPath(in: url, for: type.rawValue)
	}
	
	func hasInMemoryData(for cert: CertificatePair) -> Bool {
		return cert.p12Data != nil && cert.provisionData != nil
	}
	
	func getCertificateData(_ type: FileRequest, from cert: CertificatePair) -> Data? {
		switch type {
		case .certificate:
			guard let encryptedData = cert.p12Data else { return nil }
			return CertificateEncryption.safeDecrypt(encryptedData)
		case .provision:
			guard let encryptedData = cert.provisionData else { return nil }
			return CertificateEncryption.safeDecrypt(encryptedData)
		}
	}
	
	private func getTemporaryFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
		guard let data = getCertificateData(type, from: cert),
			  let uuid = cert.uuid else {
			return nil
		}
		
		let tempDir = FileManager.default.temporaryDirectory
		let fileName = "\(uuid)_\(type.rawValue)"
		let fileURL = tempDir.appendingPathComponent(fileName)
		
		do {
			try data.write(to: fileURL)
			return fileURL
		} catch {
			print("Failed to create temporary file: \(error)")
			return nil
		}
	}
	
	func getProvisionFileDecoded(for cert: CertificatePair) -> Certificate? {
		if let encryptedProvisionData = cert.provisionData {
			let decryptedData = CertificateEncryption.safeDecrypt(encryptedProvisionData)
			return CertificateReader.parseData(decryptedData)
		}
		
		guard let url = getFile(.provision, from: cert) else {
			return nil
		}
		
		let read = CertificateReader(url)
		return read.decoded
	}
	
	func getUuidDirectory(for cert: CertificatePair) -> URL? {
		guard let uuid = cert.uuid else {
			return nil
		}
		
		return FileManager.default.certificates(uuid)
	}
	
	func getCertificateDataForExport(from cert: CertificatePair) -> [String: Any]? {
		guard let uuid = cert.uuid else { return nil }
		
		var certData: [String: Any] = [
			"name": cert.nickname ?? "Certificate",
			"date": cert.date?.timeIntervalSince1970 ?? 0
		]
		
		if let encryptedP12Data = cert.p12Data {
			let decryptedP12Data = CertificateEncryption.safeDecrypt(encryptedP12Data)
			certData["p12Data"] = decryptedP12Data.base64EncodedString()
		} else if let p12URL = getFile(.certificate, from: cert),
		   let p12Data = try? Data(contentsOf: p12URL) {
			certData["p12Data"] = p12Data.base64EncodedString()
		} else {
			return nil
		}
		
		if let encryptedProvisionData = cert.provisionData {
			let decryptedProvisionData = CertificateEncryption.safeDecrypt(encryptedProvisionData)
			certData["provisionData"] = decryptedProvisionData.base64EncodedString()
		} else if let provisionURL = getFile(.provision, from: cert),
		   let provisionData = try? Data(contentsOf: provisionURL) {
			certData["provisionData"] = provisionData.base64EncodedString()
		} else {
			return nil
		}
		
		if let password = cert.password {
			certData["password"] = password
		}
		
		return certData
	}
}
