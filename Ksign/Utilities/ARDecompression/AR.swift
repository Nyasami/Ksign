//
//  SwiftAR.swift
//  SwiftAR
//
//  Created by nekohaxx on 8/18/24.
//

import Foundation

class AR: NSObject {
	private var _data: Data
	
	init(with url: URL) throws {
		self._data = try Data(contentsOf: url, options: .mappedIfSafe)
		super.init()
	}
	
	func extract() async throws -> [ARFileModel] {
		let magic: [UInt8] = [0x21, 0x3c, 0x61, 0x72, 0x63, 0x68, 0x3e, 0x0a]
		guard _data.count >= magic.count, Array(_data.prefix(magic.count)) == magic else {
			throw ARError.badArchive("Invalid magic")
		}
		
		let data = _data.subdata(in: 8..<_data.endIndex)
		
		var offset = 0
		var files: [ARFileModel] = []
		while offset < data.count {
			guard data.count - offset >= 60 else {
				throw ARError.badArchive("Truncated file header")
			}
			let fileInfo = try _getFileInfo(data, offset)
			files.append(fileInfo)
			offset += fileInfo.size + 60
			offset += offset % 2
		}
		return files
	}
	
	private func _getFileInfo(_ data: Data, _ offset: Int) throws -> ARFileModel {
		guard
			offset >= 0,
			data.count - offset >= 60,
			let size = Int(_field(data, offset: offset + 48, length: 10)),
			size >= 0,
			size <= data.count - offset - 60
		else {
			throw ARError.badArchive("Invalid size")
		}

		guard data[offset + 58] == 0x60, data[offset + 59] == 0x0A else {
			throw ARError.badArchive("Invalid file header")
		}
		
		var name = _field(data, offset: offset, length: 16)
		if name.hasSuffix("/") {
			name.removeLast()
		}
		guard !name.isEmpty else {
			throw ARError.badArchive("Invalid name")
		}

		guard
			let ownerID = Int(_field(data, offset: offset + 28, length: 6)),
			let groupID = Int(_field(data, offset: offset + 34, length: 6)),
			let mode = Int(_field(data, offset: offset + 40, length: 8))
		else {
			throw ARError.badArchive("Invalid file metadata")
		}
		
		return ARFileModel(
			name: name,
			modificationDate: Date(timeIntervalSince1970: Double(_field(data, offset: offset + 16, length: 12)) ?? 0),
			ownerId: ownerID,
			groupId: groupID,
			mode: mode,
			size: size,
			content: data.subdata(in: offset+60..<offset+60+size)
		)
	}
	
	private func _field(_ data: Data, offset: Int, length: Int) -> String {
		guard offset >= 0, length >= 0, offset + length <= data.count else { return "" }
		return String(data: data.subdata(in: offset..<offset+length), encoding: .ascii)?
			.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
	}
}

enum ARError: LocalizedError {
	case badArchive(String)

	var errorDescription: String? {
		switch self {
		case .badArchive(let message):
			return "Invalid AR archive: \(message)"
		}
	}
}
