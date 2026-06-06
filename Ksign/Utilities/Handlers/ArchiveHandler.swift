//
//  ArchiveHandler.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Foundation
import UIKit.UIApplication
import Zip
import SwiftUI
import IDeviceSwift

final class ArchiveHandler: NSObject {
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private var _payloadUrl: URL?
	
	private var _app: AppInfoPresentable
	private let _uniqueWorkDir: URL
	
	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
		self._app = app
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherInstall_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func move() async throws {
		guard let appUrl = Storage.shared.getAppDirectory(for: _app) else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let payloadUrl = _uniqueWorkDir.appendingPathComponent("Payload")
		let movedAppURL = payloadUrl.appendingPathComponent(appUrl.lastPathComponent)

		try _fileManager.createDirectoryIfNeeded(at: payloadUrl)
		
		try _fileManager.copyItem(at: appUrl, to: movedAppURL)
		_payloadUrl = payloadUrl
	}
	
	func archive() async throws -> URL {
		return try await Task.detached(priority: .background) { [self] in
			guard let payloadUrl = await self._payloadUrl else {
				throw SigningFileHandlerError.appNotFound
			}
			
			let zipUrl = self._uniqueWorkDir.appendingPathComponent("Archive.zip")
			let ipaUrl = self._uniqueWorkDir.appendingPathComponent("Archive.ipa")
			let compressionLevels = ZipCompression.allCases
			let compressionIndex = min(
				max(ArchiveHandler.getCompressionLevel(), 0),
				max(compressionLevels.count - 1, 0)
			)
			
			try await Zip.zipFiles(
				paths: [payloadUrl],
				zipFilePath: zipUrl,
				password: nil,
				compression: compressionLevels[compressionIndex],
				progress: { progress in
					
					Task { @MainActor in
						self.viewModel.packageProgress = progress
					}
				})
			
			try FileManager.default.moveItem(at: zipUrl, to: ipaUrl)
			return ipaUrl
		}.value
	}
	
	func moveToArchive(_ package: URL, shouldOpen: Bool = false) async throws -> URL? {
		try _fileManager.createDirectoryIfNeeded(at: _fileManager.archives)
		let rawName = await MainActor.run {
			"\(_app.name ?? "Unknown")_\(_app.version ?? "0")"
		}
		let safeName = rawName.components(separatedBy: CharacterSet(charactersIn: "/:?*<>|\"\\")).joined()
		let appendingString = "\(safeName)_\(Int(Date().timeIntervalSince1970)).ipa"
		let dest = _fileManager.archives.appendingPathComponent(appendingString)
		
		try _fileManager.moveItem(
			at: package,
			to: dest
		)
		
		if shouldOpen {
			await MainActor.run {
				if let url = FileManager.default.archives.toSharedDocumentsURL() {
					UIApplication.open(url)
				}
			}
		}
		
		return dest
	}
	
	static func getCompressionLevel() -> Int {
		UserDefaults.standard.integer(forKey: "Feather.compressionLevel")
	}
}
