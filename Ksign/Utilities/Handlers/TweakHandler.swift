//
//  DylibHandler.swift
//  feather
//
//  Created by samara on 8/17/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import Foundation
import ZsignSwift

class TweakHandler {
	private let _fileManager = FileManager.default
	private var _urlsToInject: [URL] = []
	private var _directoriesToCheck: [URL] = []

	private var _urls: [URL]
	private let _app: URL

	init(app: URL, with urls: [URL]) {
		self._app = app
		self._urls = urls
		
	}

	public func getInputFiles() async throws {
		print("DEBUG: getInputFiles called, URLs count: \(_urls.count)")
		print("DEBUG: App path: \(_app.path)")
		
		// Create Frameworks directory if it doesn't exist
		let frameworksDir = _app.appendingPathComponent("Frameworks")
		try _fileManager.createDirectoryIfNeeded(at: frameworksDir)
		
		
		// If we still have no URLs, just return - we've at least tried to replace the framework
		if _urls.isEmpty {
			print("DEBUG: No URLs to process, returning early")
			return
		}

		let baseTmpDir = _fileManager.temporaryDirectory.appendingPathComponent("FeatherTweak_\(UUID().uuidString)")
		try _fileManager.createDirectoryIfNeeded(at: baseTmpDir)
		
		// check for appropriate files, if theres debs
		// it will extract then add a url, if theres no url, i.e.
		// you haven't added a deb, it will skip
		for url in _urls {
			switch url.pathExtension.lowercased() {
			case "dylib":
				try await _handleDylib(at: url)
			case "deb":
				try await _handleDeb(at: url, baseTmpDir: baseTmpDir)
			case "framework":
				let destinationURL = _app.appendingPathComponent("Frameworks").appendingPathComponent(url.lastPathComponent)
				
				// Copy instead of move to preserve the original framework file
				if !_fileManager.fileExists(atPath: destinationURL.path) {
					try _fileManager.copyItem(at: url, to: destinationURL)
				}
				try await _handleDylib(framework: destinationURL)
			default:
				print("Unsupported file type: \(url.lastPathComponent), skipping.")
			}
		}
		
		// check contents of data.tar's extracted from debs
		if !_directoriesToCheck.isEmpty {
			try await _handleDirectories(at: _directoriesToCheck)
			if !_urlsToInject.isEmpty {
				try await _handleExtractedDirectoryContents(at: _urlsToInject)
			}
		}
	}
	
	// finally, handle extracted contents
	private func _handleExtractedDirectoryContents(at urls: [URL]) async throws {
		for url in urls {
			switch url.pathExtension.lowercased() {
			case "dylib":
				try await _handleDylib(at: url)
			case "framework":
				let destinationURL = _app.appendingPathComponent("Frameworks").appendingPathComponent(url.lastPathComponent)
				
				// Use copyItem instead of moveFileIfNeeded to preserve the original file
				if !_fileManager.fileExists(atPath: destinationURL.path) {
					try _fileManager.copyItem(at: url, to: destinationURL)
				}
				try await _handleDylib(framework: destinationURL)
			case "bundle":
				let destinationURL = _app.appendingPathComponent(url.lastPathComponent)
				
				// Use copyItem instead of moveFileIfNeeded to preserve the original file
				if !_fileManager.fileExists(atPath: destinationURL.path) {
					try _fileManager.copyItem(at: url, to: destinationURL)
				}
			default:
				print("Unsupported file type: \(url.lastPathComponent), skipping.")
			}
		}
	}
	
	// Inject imported dylib file
	private func _handleDylib(at url: URL) async throws {
		let destinationURL = _app.appendingPathComponent("Frameworks").appendingPathComponent(url.lastPathComponent)
		
		// Use copyItem instead of moveFileIfNeeded to preserve the original file
		if !_fileManager.fileExists(atPath: destinationURL.path) {
			// Create a copy using file data to avoid permission issues
			if url.startAccessingSecurityScopedResource() {
				defer { url.stopAccessingSecurityScopedResource() }
				
				// For dylibs, which are single files, use data reading
				do {
					let fileData = try Data(contentsOf: url)
					try fileData.write(to: destinationURL)
				} catch {
					// Fallback to direct copy if reading fails
					try _fileManager.copyItem(at: url, to: destinationURL)
				}
			} else {
				// Standard copy for non-secured files
				try _fileManager.copyItem(at: url, to: destinationURL)
			}
		}
		
		guard let appexe = Bundle(url: _app)?.executableURL else {
			return
		}
		
		// change paths because some tweaks hardlink, which is not ideal.
		// this is not a good solution, at most this would work for basic tweaks
		// we recommend you use newer theos to compile, and make sure it works
		// using the ellekit framework
		_ = Zsign.changeDylibPath(
			appExecutable: destinationURL.path,
			for: "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
			with: "@rpath/CydiaSubstrate.framework/CydiaSubstrate"
		)
		// inject if there's a valid app main executable
		_ = Zsign.injectDyLib(
			appExecutable: appexe.path,
			with: "@executable_path/Frameworks/\(destinationURL.lastPathComponent)"
		)
	}
	
	// Inject imported framework dir
	private func _handleDylib(framework: URL) async throws {
		guard
			let fexe = Bundle(url: framework)?.executableURL,
			let appexe = Bundle(url: _app)?.executableURL
		else {
			print("Error: Could not find executable in framework or app bundle")
			return
		}
		
		print("Processing framework: \(framework.lastPathComponent)")
		print("Framework executable: \(fexe.lastPathComponent)")
		print("App executable: \(appexe.lastPathComponent)")
		
		// Special handling for CydiaSubstrate.framework
		if framework.lastPathComponent == "CydiaSubstrate.framework" {
			print("Special handling for CydiaSubstrate.framework")
			
			// For CydiaSubstrate.framework, we don't need to modify its paths
			// since we've already bundled it correctly
			
			// Just inject it into the app executable
			let injectResult = Zsign.injectDyLib(
				appExecutable: appexe.path,
				with: "@rpath/CydiaSubstrate.framework/CydiaSubstrate"
			)
			print("Inject result for CydiaSubstrate.framework: \(injectResult)")
			
			return
		}
		
		// For other frameworks, continue with the normal process
		
		// change paths because some tweaks hardlink, which is not ideal.
		// this is not a good solution, at most this would work for basic tweaks
		// I recommend you use newer theos to compile, and make sure it works
		// using the ellekit framework
		let pathChangeResult = Zsign.changeDylibPath(
			appExecutable: fexe.path,
			for: "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
			with: "@rpath/CydiaSubstrate.framework/CydiaSubstrate"
		)
		print("Path change result for \(fexe.lastPathComponent): \(pathChangeResult)")
		
		// inject if there's a valid app main executable
		let injectResult = Zsign.injectDyLib(
			appExecutable: appexe.path,
			with: "@executable_path/Frameworks/\(framework.lastPathComponent)/\(fexe.lastPathComponent)"
		)
		print("Inject result for \(framework.lastPathComponent): \(injectResult)")
	}
	
	// Extracy imported deb file
	private func _handleDeb(at url: URL, baseTmpDir: URL) async throws {
		let uniqueSubDir = baseTmpDir.appendingPathComponent(UUID().uuidString)
		try _fileManager.createDirectoryIfNeeded(at: uniqueSubDir)
		
		// I don't particularly like this code
		// but it somehow works well enough,
		// do note large lzma's are slow as hell
		
		let handler = AR(with: url)
		let arFiles = try await handler.extract()
		
		for arFile in arFiles {
			let outputPath = uniqueSubDir.appendingPathComponent(arFile.name)
			try arFile.content.write(to: outputPath)
			
			if ["data.tar.lzma", "data.tar.gz", "data.tar.xz", "data.tar.bz2"].contains(arFile.name) {
				var fileToProcess = outputPath
				try extractFile(at: &fileToProcess)
				try extractFile(at: &fileToProcess)
				_directoriesToCheck.append(fileToProcess)
			}
		}
	}
	
	// Read extracted deb file, locate all neccessary contents to copy over to the .app
	private func _handleDirectories(at urls: [URL]) async throws {
		enum DirectoryType: String {
			case frameworks = "Frameworks"
			case dynamicLibraries = "MobileSubstrate/DynamicLibraries"
			case applicationSupport = "Application Support"
		}
		
		let directoryPaths: [DirectoryType: [String]] = [
			.frameworks: ["Library/Frameworks/", "var/jb/Library/Frameworks/"],
			.dynamicLibraries: ["Library/MobileSubstrate/DynamicLibraries/", "var/jb/Library/MobileSubstrate/DynamicLibraries/"],
			.applicationSupport: ["Library/Application Support/", "var/jb/Library/Application Support/"]
		]
				
		for baseURL in urls {
			for (directoryType, paths) in directoryPaths {
				for path in paths {
					let directoryURL = baseURL.appendingPathComponent(path)
					
					guard _fileManager.fileExists(atPath: directoryURL.path) else {
						print("Directory does not exist: \(directoryURL.path). Skipping.")
						continue
					}
					
					switch directoryType {
					case .dynamicLibraries:
						let dylibFiles = try await _locateDylibFiles(in: directoryURL)
						_urlsToInject.append(contentsOf: dylibFiles)
						
					case .frameworks:
						let frameworkDirectories = try await _locateFrameworkDirectories(in: directoryURL)
						_urlsToInject.append(contentsOf: frameworkDirectories)
						
					case .applicationSupport:
						try await _searchForBundles(in: directoryURL)
					}
				}
			}
		}
	}
}

// MARK: - Find correct files in debs
extension TweakHandler {
	private func _searchForBundles(in directory: URL) async throws {
		let fileManager = FileManager.default
		let allFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

		let bundleDirectories = allFiles.filter { url in
			let attributes = try? fileManager.attributesOfItem(atPath: url.path)
			let isSymlink = attributes?[.type] as? FileAttributeType == .typeSymbolicLink
			return url.pathExtension.lowercased() == "bundle" && url.hasDirectoryPath && !isSymlink
		}
		
		for bundleURL in bundleDirectories {
			_urlsToInject.append(bundleURL)
		}
		
		let directoriesToSearch = allFiles.filter { url in
			let attributes = try? fileManager.attributesOfItem(atPath: url.path)
			let isSymlink = attributes?[.type] as? FileAttributeType == .typeSymbolicLink
			return url.hasDirectoryPath && !bundleDirectories.contains(url) && !isSymlink
		}
		
		for dirURL in directoriesToSearch {
			try await _searchForBundles(in: dirURL)
		}
	}

	private func _locateDylibFiles(in directory: URL) async throws -> [URL] {
		let fileManager = FileManager.default
		let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])

		let dylibFiles = files.filter { url in
			let attributes = try? fileManager.attributesOfItem(atPath: url.path)
			let isSymlink = attributes?[.type] as? FileAttributeType == .typeSymbolicLink
			return url.pathExtension.lowercased() == "dylib" && !isSymlink
		}
		
		return dylibFiles
	}

	private func _locateFrameworkDirectories(in directory: URL) async throws -> [URL] {
		let fileManager = FileManager.default
		let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

		let frameworkDirectories = files.filter { url in
			let attributes = try? fileManager.attributesOfItem(atPath: url.path)
			let isSymlink = attributes?[.type] as? FileAttributeType == .typeSymbolicLink
			return url.pathExtension.lowercased() == "framework" && url.hasDirectoryPath && !isSymlink
		}
		
		return frameworkDirectories
	}
}

enum TweakHandlerError: Error {
	case unsupportedFileExtension(String)
	case decompressionFailed(String)
	case missingFile(String)
	case noAccess
}
