//
//  IPAHandler.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation
import Zip
import ZIPFoundation
import SwiftUI
import SWCompression
import Foundation.NSByteCountFormatter

final class AppFileHandler: NSObject, @unchecked Sendable {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private let _uniqueWorkDir: URL
	var uniqueWorkDirPayload: URL?

	private var _ipa: URL
	private let _install: Bool
	private let _download: Download?
	
	init(
		file ipa: URL,
		install: Bool = false,
		download: Download? = nil
	) {
		self._ipa = ipa
		self._install = install
		self._download = download
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherImport_\(_uuid)", isDirectory: true)
		
		super.init()
		print("Import initiated for: \(_ipa.lastPathComponent) with ID: \(_uuid)")
	}
	
	func copy() async throws {
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
		
		let destinationURL = _uniqueWorkDir.appendingPathComponent(_ipa.lastPathComponent)

		try _fileManager.removeFileIfNeeded(at: destinationURL)
		
		try _fileManager.copyItem(at: _ipa, to: destinationURL)
		_ipa = destinationURL
		print("[\(_uuid)] File copied to: \(_ipa.path)")
	}
	
	func extract() async throws {
		Zip.addCustomFileExtension("ipa")
		Zip.addCustomFileExtension("tipa")
		
		let download = self._download
		let library = UserDefaults.standard.string(forKey: "Feather.extractionLibrary") ?? "Zip"
		
		try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .utility).async {
				do {
					if library == "ZIPFoundation" {
						try self._ZIPFoundation(download: download)
					} else {
						try self._Zip(download: download)
					}
					self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
					continuation.resume()
				} catch {
					print("[\(self._uuid)] Extraction error: \(error.localizedDescription)")
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func _Zip(download: Download?) throws {
		try ArchivePathValidator.validateZipArchive(at: _ipa, destination: _uniqueWorkDir)
		try Zip.unzipFile(
			_ipa,
			destination: _uniqueWorkDir,
			overwrite: true,
			password: nil,
			progress: { progress in
				if let download = download {
					DispatchQueue.main.async {
						download.unpackageProgress = progress
						JobsManager.shared.update(
							download.jobID,
							progress: download.overallProgress,
							detail: .localized("Importing")
						)
                        if #available(iOS 26.0, *) {
                            BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
                        }
					}
				}
			}
		)
	}
	
	private func _ZIPFoundation(download: Download?) throws {
		let archive = try Archive(url: _ipa, accessMode: .read)
		let entries = Array(archive)
		let totalEntries = max(entries.count, 1)
		
		for (index, entry) in entries.enumerated() {
			let progress = Double(index) / Double(totalEntries)
			if let download = download {
				DispatchQueue.main.async {
					download.unpackageProgress = progress
					JobsManager.shared.update(
						download.jobID,
						progress: download.overallProgress,
						detail: .localized("Importing")
					)
                    if #available(iOS 26.0, *) {
                        BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
                    }
				}
			}
			let destinationPath = try ArchivePathValidator.destinationURL(
				base: _uniqueWorkDir,
				entryPath: entry.path
			)
			switch entry.type {
			case .directory:
				try _fileManager.createDirectory(at: destinationPath, withIntermediateDirectories: true)
			case .file:
				let parent = destinationPath.deletingLastPathComponent()
				try _fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
				try archive.extract(entry, to: destinationPath)
			case .symlink:
				throw ArchivePathError.unsupportedEntry(entry.path)
			}
		}
	}
	
	func move() async throws {
		guard let payloadURL = uniqueWorkDirPayload else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		let destinationURL = try await _directory()
		
		guard _fileManager.fileExists(atPath: payloadURL.path) else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		try _fileManager.moveItem(at: payloadURL, to: destinationURL)
		print("[\(_uuid)] Moved Payload to: \(destinationURL.path)")
		
		try? _fileManager.removeItem(at: _uniqueWorkDir)
	}
	
	func addToDatabase() async throws {
		let app = try await _directory()
		
		guard let appUrl = _fileManager.getPath(in: app, for: "app") else {
			try? _fileManager.removeItem(at: app)
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		let bundle = Bundle(url: appUrl)

		do {
			try await withCheckedThrowingContinuation { continuation in
				Storage.shared.addImported(
					uuid: _uuid,
					appName: bundle?.name,
					appIdentifier: bundle?.bundleIdentifier,
					appVersion: bundle?.version,
					appIcon: bundle?.iconFileName
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
			try? _fileManager.removeItem(at: app)
			throw error
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Unsigned/\(UUID)
		_fileManager.unsigned(_uuid)
	}
	
	func clean() async throws {
		try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
	}
}

enum ImportedFileHandlerError: Error, CustomStringConvertible, LocalizedError {
	case payloadNotFound
	case notEnoughDiskSpace(needed: Int64, available: Int64)
	case extractionFailed
	case zipLibraryNotAvailable
	
	var description: String {
		switch self {
		case .payloadNotFound:
			return "No Payload folder was found in the archive. The file may be corrupted."
		case .notEnoughDiskSpace(let needed, let available):
			let neededStr = ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)
			let availableStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
			return "Not enough disk space. Needed: \(neededStr), Available: \(availableStr)"
		case .extractionFailed:
			return "Failed to extract the archive. The file may be corrupted."
		case .zipLibraryNotAvailable:
			return "Zip library is not available on this platform."
		}
	}

	var errorDescription: String? {
		description
	}
}
