//
//  DylibsView.swift
//  Ksign
//
//  Created by Nagata Asami on 22/5/25.
//

import SwiftUI
import NimbleViews

struct DylibsView: View {
    var appPath: URL
    @Environment(\.dismiss) private var dismiss
    
    @State private var dylibFiles: [URL] = []
    @State private var selectedDylibs: [URL] = []
    @State private var isLoading = true
    @State private var showDirectoryPicker = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NBNavigationView(.localized("Frameworks & Dylibs")) {
            VStack {
                HStack {
                    Button(.localized("Done")) {
                        dismiss()
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(.localized("Copy")) {
                        showDirectoryPicker = true
                    }
                    .disabled(selectedDylibs.isEmpty)
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if dylibFiles.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            .localized("No Frameworks"),
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(.localized("No frameworks or dylibs found in this app"))
                        )
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text(.localized("No Frameworks"))
                                .font(.headline)
                            
                            Text(.localized("No frameworks or dylibs found in this app"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List(dylibFiles, id: \.absoluteString) { fileURL in
                        DylibRowView(
                            fileURL: fileURL,
                            isSelected: selectedDylibs.contains(fileURL),
                            toggleSelection: {
                                toggleDylibSelection(fileURL)
                            }
                        )
                    }
                }
            }
            .onAppear {
                loadDylibFiles()
            }
            .sheet(isPresented: $showDirectoryPicker) {
                DirectoryPickerView(onDirectorySelected: { url in
                    copyDylibsToDestination(destinationURL: url)
                })
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(.localized("OK"), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadDylibFiles() {
        isLoading = true
        dylibFiles = []
        
        let fileManager = FileManager.default
        let searchPaths = [
            appPath, // .app root
            appPath.appendingPathComponent("Frameworks") // .app/Frameworks
        ]
        
        DispatchQueue.global(qos: .userInitiated).async {
            var collectedFiles: [URL] = []
            
            for path in searchPaths {
                guard fileManager.fileExists(atPath: path.path) else { continue }
                
                do {
                    let fileURLs = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
                    let filtered = fileURLs.filter { url in
                        let ext = url.pathExtension.lowercased()
                        return ext == "framework" || ext == "dylib"
                    }
                    collectedFiles.append(contentsOf: filtered)
                } catch {
                    // Optional: handle individual folder error
                }
            }
            
            let sortedFiles = collectedFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            DispatchQueue.main.async {
                self.dylibFiles = sortedFiles
                self.isLoading = false
            }
        }
    }
    
    private func toggleDylibSelection(_ fileURL: URL) {
        if let index = selectedDylibs.firstIndex(of: fileURL) {
            selectedDylibs.remove(at: index)
        } else {
            selectedDylibs.append(fileURL)
        }
    }
    
    private func copyDylibsToDestination(destinationURL: URL) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationPath = destinationURL.path
        
        guard destinationPath.hasPrefix(documentsDirectory.path) else {
            alertTitle = .localized("Invalid Destination")
            alertMessage = .localized("The destination must be within the app's documents directory.")
            showAlert = true
            return
        }
        
        var successCount = 0
        var errorMessages: [String] = []
        
        for dylibURL in selectedDylibs {
            let fileName = dylibURL.lastPathComponent
            let destinationFileURL = destinationURL.appendingPathComponent(fileName)
            
            do {
                if fileManager.fileExists(atPath: destinationFileURL.path) {
                    try fileManager.removeItem(at: destinationFileURL)
                }
                
                try fileManager.copyItem(at: dylibURL, to: destinationFileURL)
                successCount += 1
            } catch {
                errorMessages.append("\(fileName): \(error.localizedDescription)")
            }
        }
        
        if errorMessages.isEmpty {
            alertTitle = .localized("Success")
            alertMessage = .localized("Successfully copied \(successCount) files")
        } else {
            alertTitle = .localized("Partial Success")
            alertMessage = .localized("Copied \(successCount) files") + "\n" + errorMessages.joined(separator: "\n")
        }
        
        showAlert = true
    }
}

struct DylibRowView: View {
    let fileURL: URL
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: fileURL.pathExtension.lowercased() == "framework" ? "shippingbox" : "doc.circle")
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(fileURL.lastPathComponent)
                    .font(.body)
                
                Text(fileURL.pathExtension.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection()
        }
    }
}

struct DirectoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDirectory: URL?
    @State private var currentDirectory: URL
    let onDirectorySelected: (URL) -> Void
    
    init(onDirectorySelected: @escaping (URL) -> Void) {
        self.onDirectorySelected = onDirectorySelected
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        _currentDirectory = State(initialValue: documentsDirectory)
    }
    
    var body: some View {
        NBNavigationView(.localized("Select Destination")) {
            VStack {
                HStack {
                    Button(.localized("Cancel")) {
                        dismiss()
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(.localized("Select")) {
                        onDirectorySelected(currentDirectory)
                        dismiss()
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                
                List {
                    Section {
                        Text(currentDirectory.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(.localized("Directories")) {
                        ForEach(getDirectories(), id: \.absoluteString) { url in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.accentColor)
                                Text(url.lastPathComponent)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentDirectory = url
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getDirectories() -> [URL] {
        let fileManager = FileManager.default
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            return urls.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return []
        }
    }
} 
