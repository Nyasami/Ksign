//
//  FileManager+documents.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation.NSFileManager

extension FileManager {
	/// Gives apps Signed directory
	var archives: URL {
		URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Archives")
	}
	
	/// Gives apps Signed directory
	var signed: URL {
		URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Signed")
	}
	
	/// Gives apps Signed directory with a UUID appending path
	func signed(_ uuid: String) -> URL {
		signed.appendingPathComponent(uuid)
	}
	
	/// Gives apps Unsigned directory
	var unsigned: URL {
		URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Unsigned")
	}
	
	/// Gives apps Unsigned directory with a UUID appending path
	func unsigned(_ uuid: String) -> URL {
		unsigned.appendingPathComponent(uuid)
	}
	
	/// Gives apps Certificates directory (stored in Application Support for security)
	var certificates: URL {
		do {
			let applicationSupport = try FileManager.default.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let certificatesDirectory = applicationSupport.appendingPathComponent("Certificates")
			
			// Create the directory if it doesn't exist
			if !FileManager.default.fileExists(atPath: certificatesDirectory.path) {
				try FileManager.default.createDirectory(at: certificatesDirectory, withIntermediateDirectories: true)
			}
			
			return certificatesDirectory
		} catch {
			// Fallback to documents directory if Application Support isn't available
			print("Error accessing Application Support: \(error)")
			return URL.documentsDirectory.appendingPathComponent("Certificates")
		}
	}
	
	/// Gives apps Certificates directory with a UUID appending path
	func certificates(_ uuid: String) -> URL {
		certificates.appendingPathComponent(uuid)
	}
	
	/// Gives apps Tweaks directory
	var tweaks: URL {
		URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Tweaks")
	}
}
