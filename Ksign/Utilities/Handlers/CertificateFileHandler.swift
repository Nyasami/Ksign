//
//  CertificateFileHandler.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import Foundation

final class CertificateFileHandler: NSObject {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	
	private let _key: URL
	private let _provision: URL
	private let _keyPassword: String?
	private let _certNickname: String?
	
	private var _certPair: Certificate?
	
	init(
		key: URL,
		provision: URL,
		password: String? = nil,
		nickname: String? = nil
	) {
		self._key = key
		self._provision = provision
		self._keyPassword = password
		self._certNickname = nickname
		
		_certPair = CertificateReader(provision).decoded
		
		super.init()
	}
	
	func copy() async throws {
		guard
			(_certPair != nil)
		else  {
			throw CertificateFileHandlerError.certNotValid
		}
		
		let destinationURL = try await _directory()

		do {
			try _fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
			try _fileManager.copyItem(at: _key, to: destinationURL.appendingPathComponent(_key.lastPathComponent))
			try _fileManager.copyItem(at: _provision, to: destinationURL.appendingPathComponent(_provision.lastPathComponent))
		} catch {
			try? _fileManager.removeItem(at: destinationURL)
			throw error
		}
	}
	
	func addToDatabase() async throws {
		do {
			try await withCheckedThrowingContinuation { continuation in
				Storage.shared.addCertificate(
					uuid: _uuid,
					password: _keyPassword,
					nickname: _certNickname,
					ppq: _certPair?.PPQCheck ?? false,
					expiration: _certPair?.ExpirationDate ?? Date()
				) { error in
					if let error {
						continuation.resume(throwing: error)
					} else {
						print("[\(self._uuid)] Added to database")
						continuation.resume()
					}
				}
			}
		} catch {
			if let directory = try? await _directory() {
				try? _fileManager.removeItem(at: directory)
			}
			throw error
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Certificates/\(UUID)
		_fileManager.certificates(_uuid)
	}
}

private enum CertificateFileHandlerError: LocalizedError {
	case certNotValid

	var errorDescription: String? {
		"The certificate provisioning profile is invalid."
	}
}
