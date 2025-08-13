//
//  FilesViewModel.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//



import SwiftUI
import UniformTypeIdentifiers
import Zip
import SWCompression
import ArArchiveKit
import Zsign

class FilesViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var isLoading = false
    @Published var currentDirectory: URL
    @Published var selectedItems: Set<FileItem> = []
    @Published var isEditMode: EditMode = .inactive
    @Published var error: String?
    @Published var showingError = false
    @Published var showingNewFolderDialog = false
    @Published var newFolderName = ""
    @Published var showingImporter = false
    @Published var showRenameDialog = false
    @Published var itemToRename: FileItem?
    @Published var newFileName = ""
    @Published var showActionSheet = false
    @Published var selectedItem: FileItem?
    @Published var showPasswordAlert = false
    @Published var certificatePassword = ""
    @Published var selectedP12File: FileItem?
    @Published var selectedProvisionFile: FileItem?
    @Published var showDirectoryPicker = false
    @Published var selectedDestinationDirectory: URL?
    

    
    init(directory: URL? = nil) {
        if let directory = directory {
            self.currentDirectory = directory
        } else if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.currentDirectory = documentsDirectory
        } else {
            self.currentDirectory = URL(fileURLWithPath: "")
        }
    }
    
    func loadFiles() {
        isLoading = true
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey])
            
            files = contents.compactMap { url in
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    let creationDate = resourceValues.creationDate
                    let size = resourceValues.fileSize ?? 0
                    
                    return FileItem(
                        name: url.lastPathComponent,
                        url: url,
                        size: Int64(size),
                        creationDate: creationDate,
                        isDirectory: isDirectory
                    )
                } catch {
                    print("Error getting file attributes: \(error)")
                    return nil
                }
            }.sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            isLoading = false
        } catch {
            isLoading = false
            self.error = "Error loading files: \(error.localizedDescription)"
            self.showingError = true
        }
    }
    

    
    func deleteFile(_ fileItem: FileItem) {
        delete(items: [fileItem])
    }
    
    func deleteSelectedItems() {
        guard !selectedItems.isEmpty else { return }
        
        let itemsToDelete = Array(selectedItems)
        
        delete(items: itemsToDelete)

        selectedItems.removeAll()
        if isEditMode == .active {
            isEditMode = .inactive
        }
    }

    private func delete(items: [FileItem]) {
        guard !items.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            var errorMessages: [String] = []
            
            for item in items {
                do {
                    try fileManager.removeItem(at: item.url)
                    
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if let index = self.files.firstIndex(where: { $0.url == item.url }) {
                                self.files.remove(at: index)
                            }
                        }
                    }
                } catch {
                    errorMessages.append(item.name)
                }
            }
            
            DispatchQueue.main.async {
                if !errorMessages.isEmpty {
                    let count = errorMessages.count
                    self.error = "Failed to delete \(count) item\(count == 1 ? "" : "s")"
                    self.showingError = true
                }
            }
        }
    }
    
    func createNewFolder() {
        guard !newFolderName.isEmpty else { return }
        
        let sanitizedName = sanitizeFileName(newFolderName)
        let newFolderURL = currentDirectory.appendingPathComponent(sanitizedName)
        
        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: true, attributes: nil)
            newFolderName = ""
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadFiles()
            }
        } catch {
            self.error = "Error creating folder: \(error.localizedDescription)"
            self.showingError = true
        }
    }
    

    
    func renameFile() {
        guard let item = itemToRename, !newFileName.isEmpty else { return }
        
        let sanitizedName = sanitizeFileName(newFileName)
        let newURL = currentDirectory.appendingPathComponent(sanitizedName)
        
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            newFileName = ""
            itemToRename = nil
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadFiles()
            }
        } catch {
            self.error = "Error renaming file: \(error.localizedDescription)"
            self.showingError = true
        }
    }
    

    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:?*<>|\"\\")
        return name.components(separatedBy: invalidCharacters).joined()
    }
    
    func importFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            var failureCount = 0
            
            for url in urls {
                do {
                    guard fileManager.fileExists(atPath: url.path) else {
                        throw NSError(domain: "FileImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source file not accessible: \(url.lastPathComponent)"])
                    }
                    
                    let destinationURL = self.currentDirectory.appendingPathComponent(url.lastPathComponent)
                    let finalDestinationURL = self.generateUniqueFileName(for: destinationURL)
                    
                    try self.importSingleItem(from: url, to: finalDestinationURL)
                } catch {
                    failureCount += 1
                }
            }
            
            DispatchQueue.main.async {
                if failureCount > 0 {
                    self.error = "Failed to import \(failureCount) file\(failureCount == 1 ? "" : "s")"
                    self.showingError = true
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.loadFiles()
                }
            }
        }
    }
    
    private func importSingleItem(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw NSError(
                domain: "FileImportError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Source does not exist: \(sourceURL.path)"]
            )
        }
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw NSError(
                domain: "FileImportError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to copy file: \(error.localizedDescription)"]
            )
        }
    }
    

    
    private func generateUniqueFileName(for url: URL) -> URL {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            return url
        }
        
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        
        var counter = 1
        var newURL: URL
        
        repeat {
            let newFilename = pathExtension.isEmpty 
                ? "\(filename) (\(counter))"
                : "\(filename) (\(counter)).\(pathExtension)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path) && counter < 1000 // Safety limit
        
        return newURL
    }
    
    func importCertificate(_ file: FileItem) {
        guard file.isP12Certificate else { return }
        
        CertificateService.shared.importP12Certificate(from: file) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.error = message
                    self?.showingError = true
                case .failure(let importError):
                    if case .invalidPassword = importError {
                        self?.selectedP12File = file
                        self?.certificatePassword = ""
                        self?.showPasswordAlert = true
                    } else {
                        self?.error = importError.localizedDescription
                        self?.showingError = true
                    }
                }
            }
        }
    }
    
    func completeCertificateImport() {
        guard let p12File = selectedP12File else { return }
        
        let directory = p12File.url.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let provisionFiles = directoryContents.filter { url in
                url.pathExtension.lowercased() == "mobileprovision"
            }
            
            guard let provisionURL = provisionFiles.first else {
                self.error = "No .mobileprovision file found in the same directory"
                self.showingError = true
                return
            }
            
            let resourceValues = try provisionURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey])
            let provisionFile = FileItem(
                name: provisionURL.lastPathComponent,
                url: provisionURL,
                size: Int64(resourceValues.fileSize ?? 0),
                creationDate: resourceValues.creationDate,
                isDirectory: resourceValues.isDirectory ?? false
            )
            
            CertificateService.shared.importP12Certificate(
                p12File: p12File,
                provisionFile: provisionFile,
                password: certificatePassword
            ) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let message):
                        self?.error = message
                        self?.showingError = true
                    case .failure(let importError):
                        self?.error = importError.localizedDescription
                        self?.showingError = true
                    }
                    
                    self?.selectedP12File = nil
                    self?.selectedProvisionFile = nil
                    self?.certificatePassword = ""
                }
            }
            
        } catch {
            self.error = "Error finding provision file: \(error.localizedDescription)"
            self.showingError = true
        }
    }
    
    func importKsignFile(_ file: FileItem) {
        guard file.isKsignFile else { return }
        
        CertificateService.shared.importKsignCertificate(from: file) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.error = message
                    self?.showingError = true
                case .failure(let importError):
                    self?.error = importError.localizedDescription
                    self?.showingError = true
                }
            }
        }
    }

    
    func moveFiles(to destinationURL: URL) {
        let fileManager = FileManager.default
        var successCount = 0
        var failCount = 0
        
        for item in selectedItems {
            let destinationFileURL = destinationURL.appendingPathComponent(item.name)
            
            do {
                if fileManager.fileExists(atPath: destinationFileURL.path) {
                    failCount += 1
                    continue
                }
                
                try fileManager.moveItem(at: item.url, to: destinationFileURL)
                successCount += 1
            } catch {
                print("Error moving file: \(error)")
                failCount += 1
            }
        }
        
        withAnimation {
            selectedItems.removeAll()
            if isEditMode == .active {
                isEditMode = .inactive
            }
        }
        
        if failCount == 0 {
            self.error = "Successfully moved \(successCount) items"
        } else {
            self.error = "Moved \(successCount) items. Failed to move \(failCount) items."
        }
        self.showingError = true
        
        loadFiles()
    }
    
    func extractArchive(_ file: FileItem) {
        guard file.isArchive else { return }
        
        NotificationCenter.default.post(name: NSNotification.Name("ExtractionStarted"), object: nil)
        
        ExtractionService.extractArchive(file, to: currentDirectory) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    NotificationCenter.default.post(name: NSNotification.Name("ExtractionCompleted"), object: nil)
                    
                    withAnimation {
                        self?.loadFiles()
                    }
                    
                    self?.error = "File extracted successfully"
                    self?.showingError = true
                    
                case .failure(let error):
                    NotificationCenter.default.post(name: NSNotification.Name("ExtractionFailed"), object: nil)
                    self?.error = "Error extracting archive: \(error.localizedDescription)"
                    self?.showingError = true
                }
            }
        }
    }
    
    func packageAppAsIPA(_ file: FileItem) {
        guard file.isAppDirectory else { return }
        
        NotificationCenter.default.post(name: NSNotification.Name("ExtractionStarted"), object: nil)
        
        ExtractionService.packageAppAsIPA(file, to: currentDirectory) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ipaFileName):
                    NotificationCenter.default.post(name: NSNotification.Name("ExtractionCompleted"), object: nil)
                    self?.loadFiles()
                    self?.error = "Successfully packaged \(file.name) as \(ipaFileName)"
                    self?.showingError = true
                    
                case .failure(let error):
                    NotificationCenter.default.post(name: NSNotification.Name("ExtractionFailed"), object: nil)
                    self?.error = "Failed to package IPA: \(error.localizedDescription)"
                    self?.showingError = true
                }
            }
        }
    }
    
} 
