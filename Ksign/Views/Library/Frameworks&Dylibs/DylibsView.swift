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
    var appName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var dylibFiles: [URL] = []
    @State private var selectedDylibs: [URL] = []
    @State private var showDirectoryPicker = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NBNavigationView(appName, displayMode: .inline) {
            VStack {
                List(dylibFiles, id: \.absoluteString) { fileURL in
                    DylibRowView(
                        fileURL: fileURL,
                        isSelected: selectedDylibs.contains(fileURL),
                        toggleSelection: {
                            toggleDylibSelection(fileURL)
                        }
                    )
                }
                .listStyle(.plain)
            }
            .overlay(alignment: .center) {
                if dylibFiles.isEmpty {
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
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(.localized("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(.localized("Copy")) {
                        showDirectoryPicker = true
                    }
                    .disabled(selectedDylibs.isEmpty)
                }
            }
            .onAppear {
                loadDylibFiles()
            }
            .sheet(isPresented: $showDirectoryPicker) {
                FileExporterRepresentableView(
                    urlsToExport: selectedDylibs,
                    asCopy: true,
                    onCompletion: { _ in
                        selectedDylibs.removeAll()
                    }
                )
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(.localized("OK"), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadDylibFiles() {
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
    
}
