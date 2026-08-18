//
//  DylibsView.swift
//  Ksign
//
//  Created by Nagata Asami on 22/5/25.
//

import SwiftUI
import NimbleViews
import ZsignSwift

struct DylibsView: View {
    var app: AppInfoPresentable
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false
    
    @State private var dylibFiles: [URL] = []
    @State private var selectedDylibs: [URL] = []
    @State private var showDirectoryPicker = false
    @State private var hiddenDylibCount: Int = 0
    @State private var searchText: String = ""
    var body: some View {
        NBNavigationView(app.name ?? .localized("Frameworks & Dylibs"), displayMode: .inline) {
            VStack {
                List(dylibFiles.filter { searchText.isEmpty ? true : $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }, id: \.absoluteString) { fileURL in
                    DylibRowView(
                        fileURL: fileURL,
                        isSelected: selectedDylibs.contains(fileURL),
                        toggleSelection: {
                            toggleDylibSelection(fileURL)
                        }
                    )
                }
                .listStyle(.plain)
                if hiddenDylibCount > 0 {
                    Text(verbatim: .localized("%lld required system dylibs not shown", arguments: hiddenDylibCount))
                        .font(.footnote)
                        .foregroundColor(.disabled())
                }
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
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        FRAppIconView(app: app, size: 28)
                        Text(app.name ?? .localized("Frameworks & Dylibs"))
                            .font(.headline)
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
                    useLastLocation: _useLastExportLocation,
                    onCompletion: { _ in
                        selectedDylibs.removeAll()
                    }
                )
            }
            .searchable(text: $searchText)
        }
    }
    
    private func loadDylibFiles() {
        dylibFiles = []
        hiddenDylibCount = 0
        guard let appPath = Storage.shared.getAppDirectory(for: app) else { return }
        let bundle = Bundle(url: appPath)
        let execPath = appPath.appendingPathComponent(bundle?.exec ?? "").relativePath
        let allDylibs = Zsign.listDylibs(appExecutable: execPath).map { $0 as String }
        let visibleDylibs = allDylibs.filter { $0.hasPrefix("@rpath") || $0.hasPrefix("@executable_path") }
        hiddenDylibCount = allDylibs.count - visibleDylibs.count
        
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
                self.hiddenDylibCount = hiddenDylibCount
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
