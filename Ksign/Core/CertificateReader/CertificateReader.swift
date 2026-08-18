//
//  CertificateReader.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import UIKit

class CertificateReader: NSObject {
	let file: URL?
	var decoded: Certificate?
	
	init(_ file: URL?) {
		self.file = file
		super.init()
		self.decoded = self._readAndDecode()
	}
	
	private func _readAndDecode() -> Certificate? {
		guard let file = file else { return nil }
		
		do {
			let fileData = try Data(contentsOf: file)
			return Self.parseData(fileData)
		} catch {
			print("Error reading certificate file: \(error.localizedDescription)")
			return nil
		}
	}
	
	// Static method to parse certificate data directly
	static func parseData(_ data: Data) -> Certificate? {
		do {
			guard let xmlRange = data.range(of: Data("<?xml".utf8)) else {
				print("XML start not found")
				return nil
			}
			
			let xmlData = data.subdata(in: xmlRange.lowerBound..<data.endIndex)
			
			let decoder = PropertyListDecoder()
			let certificate = try decoder.decode(Certificate.self, from: xmlData)
			return certificate
		} catch {
			print("Error extracting certificate: \(error.localizedDescription)")
			return nil
		}
	}
}
