//
//  ExtractionService.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import Foundation
import Zip
import SWCompression
import ArArchiveKit
import ZIPFoundation

class ExtractionService {
    static func extractArchive(
        _ file: FileItem,
        to destinationDirectory: URL,
        progressCallback: ((Double) -> Void)? = nil,
        completionCallback: @escaping (Result<Void, Error>) -> Void
    ) {
        guard file.isArchive else {
            completionCallback(.failure(ExtractionError.notAnArchive))
            return
        }
        
        let fileNameWithoutExtension: String
        if let ext = file.fileExtension {
            fileNameWithoutExtension = file.name.replacingOccurrences(of: ".\(ext)", with: "")
        } else {
            fileNameWithoutExtension = file.name
        }
        
        let destinationURL = destinationDirectory.appendingPathComponent(fileNameWithoutExtension)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                
                progressCallback?(0.1)
                
                if file.isZipArchive {
                    try extractZipArchive(file.url, to: destinationURL, progressCallback: progressCallback)
                } else if file.isDebArchive {
                    try extractDebArchive(file.url, to: destinationURL, progressCallback: progressCallback)
                }
                
                progressCallback?(1.0)
                completionCallback(.success(()))
                
            } catch {
                completionCallback(.failure(error))
            }
        }
    }
    
    static func packageAppAsIPA(
        _ file: FileItem,
        to destinationDirectory: URL,
        progressCallback: ((Double) -> Void)? = nil,
        completionCallback: @escaping (Result<String, Error>) -> Void
    ) {
        guard file.isAppDirectory else {
            completionCallback(.failure(ExtractionError.notAnAppDirectory))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let appNameWithoutExtension = file.name.replacingOccurrences(of: ".app", with: "")
                
                let tempDir = FileManager.default.temporaryDirectory
                let payloadDir = tempDir.appendingPathComponent("Payload")
                let ipaFileName = "\(appNameWithoutExtension).ipa"
                let zipFilePath = destinationDirectory.appendingPathComponent("\(appNameWithoutExtension).zip")
                let ipaFilePath = destinationDirectory.appendingPathComponent(ipaFileName)
                
                progressCallback?(0.1)
                
                try? FileManager.default.removeItem(at: payloadDir)
                try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
                
                progressCallback?(0.2)
                
                let appInPayloadPath = payloadDir.appendingPathComponent(file.name)
                try FileManager.default.copyItem(at: file.url, to: appInPayloadPath)
                
                progressCallback?(0.4)

                try? FileManager.default.removeItem(at: zipFilePath)
                try? FileManager.default.removeItem(at: ipaFilePath)
                
                try Zip.zipFiles(paths: [payloadDir], zipFilePath: zipFilePath, password: nil, progress: { zipProgress in
                    progressCallback?(0.4 + (zipProgress * 0.5))
                })
                
                progressCallback?(0.95)
                
                try FileManager.default.moveItem(at: zipFilePath, to: ipaFilePath)
                
                try? FileManager.default.removeItem(at: payloadDir)
                
                progressCallback?(1.0)
                completionCallback(.success(ipaFileName))
                
            } catch {
                completionCallback(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private static func extractZipArchive(
        _ fileURL: URL,
        to destinationURL: URL,
        progressCallback: ((Double) -> Void)?
    ) throws {
        let library = _selectedExtractionLibrary()
        switch library {
        case "ZIPFoundation":
            try _ZIPFoundation(fileURL, to: destinationURL, progressCallback: progressCallback)
        default:
            try _Zip(fileURL, to: destinationURL, progressCallback: progressCallback)
        }
    }
    
    private static func _selectedExtractionLibrary() -> String {
        return UserDefaults.standard.string(forKey: "Feather.extractionLibrary") ?? "Zip"
    }
    
    private static func _Zip(
        _ fileURL: URL,
        to destinationURL: URL,
        progressCallback: ((Double) -> Void)?
    ) throws {
        Zip.addCustomFileExtension("ipa")
        if let progressCallback = progressCallback {
            try Zip.unzipFile(fileURL, destination: destinationURL, overwrite: true, password: nil, progress: progressCallback)
        } else {
            try Zip.unzipFile(
                fileURL,
                destination: destinationURL,
                overwrite: true,
                password: nil
            )
        }
    }
    
    private static func _ZIPFoundation(
        _ fileURL: URL,
        to destinationURL: URL,
        progressCallback: ((Double) -> Void)?
    ) throws {
        let archive = try Archive(url: fileURL, accessMode: .read)
        let entries = Array(archive)
        let totalEntries = max(entries.count, 1)
        
        for (index, entry) in entries.enumerated() {
            let progress = Double(index) / Double(totalEntries)
            progressCallback?(progress)
            
            let destinationPath = destinationURL.appendingPathComponent(entry.path)
            switch entry.type {
            case .directory:
                try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
            default:
                let parent = destinationPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                try archive.extract(entry, to: destinationPath)
            }
        }
    }
    
    private static func extractDebArchive(
        _ fileURL: URL,
        to destinationURL: URL,
        progressCallback: ((Double) -> Void)?
    ) throws {
        let debData = try Data(contentsOf: fileURL)
        let archiveBytes = Array(debData)
        
        progressCallback?(0.2)
        
        let reader = try ArArchiveReader(archive: archiveBytes)
        
        progressCallback?(0.3)
        
        for (header, data) in reader {
            print("Processing AR entry: \(header.name)")
            
            if header.name.hasPrefix("data.tar") {
                progressCallback?(0.4)
                
                if header.name.hasSuffix(".xz") {
                    let decompressedData = try SWCompression.XZArchive.unarchive(archive: Data(data))
                    let tarEntries = try SWCompression.TarContainer.open(container: decompressedData)
                    try extractTarEntries(tarEntries, to: destinationURL)
                } else if header.name.hasSuffix(".gz") {
                    let decompressedData = try SWCompression.GzipArchive.unarchive(archive: Data(data))
                    let tarEntries = try SWCompression.TarContainer.open(container: decompressedData)
                    try extractTarEntries(tarEntries, to: destinationURL)
                } else if header.name == "data.tar" {
                    let tarEntries = try SWCompression.TarContainer.open(container: Data(data))
                    try extractTarEntries(tarEntries, to: destinationURL)
                } else if header.name.hasSuffix(".lzma") {
                    let decompressedData = try SWCompression.LZMA.decompress(data: Data(data))
                    let tarEntries = try SWCompression.TarContainer.open(container: decompressedData)
                    try extractTarEntries(tarEntries, to: destinationURL)
                } else if header.name.hasSuffix(".bz2") {
                    let decompressedData = try SWCompression.BZip2.decompress(data: Data(data))
                    let tarEntries = try SWCompression.TarContainer.open(container: decompressedData)
                    try extractTarEntries(tarEntries, to: destinationURL)
                }
                
                progressCallback?(0.9)
            }
        }
    }
    
    private static func extractTarEntries(_ entries: [TarEntry], to destinationURL: URL) throws {
        for entry in entries {
            let entryPath = entry.info.name
            let fullPath = destinationURL.appendingPathComponent(entryPath)
            
            if entry.info.type == .directory {
                try FileManager.default.createDirectory(at: fullPath, withIntermediateDirectories: true)
            } else if entry.info.type == .regular {
                let parentDir = fullPath.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                
                try entry.data?.write(to: fullPath)
            }
            // Note: Symbolic links and other special types are ignored for simplicity
        }
    }
}

// MARK: - Error Types

enum ExtractionError: LocalizedError {
    case notAnArchive
    case notAnAppDirectory
    case extractionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAnArchive:
            return "File is not a supported archive format"
        case .notAnAppDirectory:
            return "File is not an .app directory"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        }
    }
} 