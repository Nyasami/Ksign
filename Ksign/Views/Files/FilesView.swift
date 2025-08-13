//
//  FilesView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import NimbleViews

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct FilesView: View {
    let directoryURL: URL?
    let isRootView: Bool
    
    @StateObject private var viewModel: FilesViewModel
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var searchText = ""
    @Namespace private var animation

    @State private var extractionProgress: Double = 0
    @State private var isExtracting = false
    @State private var plistFileURL: URL?
    @State private var hexEditorFileURL: URL?
    @State private var moveSingleFile: FileItem?
    @State private var showFilePreview = false
    @State private var previewFile: FileItem?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var navigateToDirectoryURL: URL?
    
    // MARK: - Initializers
    
    init() {
        self.directoryURL = nil
        self.isRootView = true
        self._viewModel = StateObject(wrappedValue: FilesViewModel())
    }
    
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.isRootView = false
        self._viewModel = StateObject(wrappedValue: FilesViewModel(directory: directoryURL))
    }
    
    private var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return viewModel.files
        } else {
            return viewModel.files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        Group {
            if isRootView {
                NavigationStack {
                    filesBrowserContent
                }
                .accentColor(.accentColor)
            } else {
                filesBrowserContent
            }
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            if !isRootView {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    // MARK: - Main Content
    
    private var filesBrowserContent: some View {
        ZStack {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "Search files"))
                .refreshable {
                    if isRootView {
                        await withCheckedContinuation { continuation in
                            viewModel.loadFiles()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                continuation.resume()
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        addButton
                        editButton
                    }
                    if viewModel.isEditMode == .active {
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: 12) {
                                selectAllButton
                                moveButton
                                shareButton
                                deleteButton
                            }
                        }
                    }
                }
            
            if isExtracting {
                extractionProgressView
            }
        }
        .sheet(isPresented: $viewModel.showingImporter) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType.item],
                allowsMultipleSelection: true,
                onDocumentsPicked: { urls in
                    viewModel.importFiles(urls: urls)
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(item: $moveSingleFile) { item in
            FileExporterRepresentableView(
                urlsToExport: [item.url],
                asCopy: false,
                onCompletion: { _ in
                    moveSingleFile = nil
                    viewModel.loadFiles()
                }
            )
        }
        .sheet(isPresented: $viewModel.showDirectoryPicker) {
            FileExporterRepresentableView(
                urlsToExport: Array(viewModel.selectedItems.map { $0.url }),
                asCopy: false,
                onCompletion: { _ in
                    viewModel.selectedItems.removeAll()
                    if viewModel.isEditMode == .active { viewModel.isEditMode = .inactive }
                
                    viewModel.loadFiles()
                }
            )
        }

        .fullScreenCover(item: $plistFileURL) { fileURL in
            PlistEditorView(fileURL: fileURL)
        }
        .fullScreenCover(item: $hexEditorFileURL) { fileURL in
            HexEditorView(fileURL: fileURL)
        }
        .alert(String(localized: "New Folder"), isPresented: $viewModel.showingNewFolderDialog) {
            TextField(String(localized: "Folder name"), text: $viewModel.newFolderName)
                .autocapitalization(.words)
                .disableAutocorrection(true)
            Button(String(localized: "Cancel"), role: .cancel) { viewModel.newFolderName = "" }
            Button(String(localized: "Create")) { viewModel.createNewFolder() }
        } message: {
            Text(String(localized: "Enter a name for the new folder"))
        }
        .alert(String(localized: "Rename File"), isPresented: $viewModel.showRenameDialog) {
            TextField(String(localized: "File name"), text: $viewModel.newFileName)
                .disableAutocorrection(true)
            Button(String(localized: "Cancel"), role: .cancel) { 
                viewModel.itemToRename = nil
                viewModel.newFileName = "" 
            }
            Button(String(localized: "Rename")) { viewModel.renameFile() }
        } message: {
            Text(String(localized: "Enter a new name"))
        }
        .alert(isPresented: $viewModel.showingError) {
            Alert(
                title: Text(String(localized: "Success")),
                message: Text(viewModel.error ?? String(localized: "An unknown error occurred")),
                dismissButton: .default(Text(String(localized: "OK")))
            )
        }
        .alert(String(localized: "Enter Certificate Password"), isPresented: $viewModel.showPasswordAlert) {
            TextField(String(localized: "Password (leave empty if none)"), text: $viewModel.certificatePassword)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button(String(localized: "Cancel"), role: .cancel) { 
                viewModel.selectedP12File = nil
                viewModel.selectedProvisionFile = nil
                viewModel.certificatePassword = ""
            }
            Button(String(localized: "Import")) { viewModel.completeCertificateImport() }
        } message: {
            Text(String(localized: "Enter the password for the certificate. Leave it blank if no password is required."))
        }
        .onAppear {
            if !isRootView {
                setupNotifications()
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else {
                fileListView
            }
        }
        .overlay {
            if filteredFiles.isEmpty && !viewModel.isLoading {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("No Files"), systemImage: "folder.fill.badge.questionmark")
                    } description: {
                        Text(.localized("Get started by importing your first file."))
                    } actions: {
                        Button {
                            viewModel.showingImporter = true
                        } label: {
                            Text("Import Files").bg()
                        }
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var fileListView: some View {
        List {
            ForEach(filteredFiles) { file in
                FileRow(
                    file: file,
                    isSelected: viewModel.selectedItems.contains(file),
                    viewModel: viewModel,
                    plistFileURL: $plistFileURL,
                    hexEditorFileURL: $hexEditorFileURL,
                    shareItems: $shareItems,
                    showingShareSheet: $showingShareSheet,
                    moveFileItem: $moveSingleFile,
                    onExtractArchive: extractArchive,
                    onPackageApp: packageAppAsIPA,
                    onImportIpa: importIpaToLibrary,
                    onPresentQuickLook: presentQuickLook,
                    onNavigateToDirectory: navigateToDirectory
                )
                .swipeActions(edge: .trailing) {
                    swipeActions(for: file)
                }
                .listRowBackground(selectionBackground(for: file))
                
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $viewModel.isEditMode)
        .navigationDestination(isPresented: Binding(
            get: { navigateToDirectoryURL != nil },
            set: { if !$0 { navigateToDirectoryURL = nil } }
        )) {
            if let url = navigateToDirectoryURL {
                FilesView(directoryURL: url)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var navigationTitle: String {
        if let directoryURL = directoryURL {
            return directoryURL.lastPathComponent
        } else {
            return viewModel.currentDirectory.lastPathComponent
        }
    }
    
    private var extractionProgressView: some View {
        FileUIHelpers.extractionProgressView(progress: extractionProgress)
    }
    
    // MARK: - Setup Methods
    
    private func setupView() {
        viewModel.loadFiles()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionStarted"), object: nil, queue: .main) { _ in
            self.isExtracting = true
            self.extractionProgress = 0.1
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionCompleted"), object: nil, queue: .main) { _ in
            self.extractionProgress = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    self.isExtracting = false
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionFailed"), object: nil, queue: .main) { _ in
            self.isExtracting = false
        }
        
   
    }
    
    // MARK: - Toolbar Items
    
    private var addButton: some View {
        Menu {
            Button {
                viewModel.showingImporter = true
            } label: {
                Label(String(localized: "Import Files"), systemImage: "doc.badge.plus")
            }
            .tint(.primary)
            Button {
                viewModel.showingNewFolderDialog = true
            } label: {
                Label(String(localized: "New Folder"), systemImage: "folder.badge.plus")
            }
            .tint(.primary)
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
    
    private var editButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                viewModel.isEditMode = viewModel.isEditMode == .active ? .inactive : .active
                if viewModel.isEditMode == .inactive {
                    viewModel.selectedItems.removeAll()
                }
            }
        } label: {
            Text(viewModel.isEditMode == .active ? String(localized: "Done") : String(localized: "Edit"))
        }
    }
    
    private var selectAllButton: some View {
        Button {
            if viewModel.selectedItems.isEmpty {
                for file in viewModel.files {
                    viewModel.selectedItems.insert(file)
                }
            } else {
                viewModel.selectedItems.removeAll()
            }
        } label: {
            Image(systemName: viewModel.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
        }
    }
    
    private var moveButton: some View {
        Button {
            viewModel.showDirectoryPicker = true
        } label: {
            Label(String(localized: "Move"), systemImage: "folder")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var shareButton: some View {
        Button {
            if !viewModel.selectedItems.isEmpty {
                let urls = viewModel.selectedItems.map { $0.url }
                shareItems = urls
                showingShareSheet = true
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.deleteSelectedItems()
        } label: {
            Image(systemName: "trash")
                .tint(.red)
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    // MARK: - Actions
    
    private func navigateToDirectory(_ url: URL) {
        navigateToDirectoryURL = url
    }
    

    
    // MARK: - File Operations
    
    private func extractArchive(_ file: FileItem) {
        guard file.isArchive else { return }
        
        isExtracting = true
        extractionProgress = 0.0
        
        ExtractionService.extractArchive(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    self.extractionProgress = progress
                }
            }
        ) { result in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                switch result {
                case .success:
                    withAnimation {
                        self.viewModel.loadFiles()
                    }
                    self.viewModel.error = String(localized: "File extracted successfully")
                    self.viewModel.showingError = true
                    
                case .failure(let error):
                    self.viewModel.error = String(localized: "Error extracting archive: \(error.localizedDescription)")
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func packageAppAsIPA(_ file: FileItem) {
        guard file.isAppDirectory else { return }
        
        isExtracting = true
        extractionProgress = 0.0
        
        ExtractionService.packageAppAsIPA(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    self.extractionProgress = progress
                }
            }
        ) { result in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                switch result {
                case .success(let ipaFileName):
                    self.viewModel.loadFiles()
                    self.viewModel.error = String(localized: "Successfully packaged \(file.name) as \(ipaFileName)")
                    self.viewModel.showingError = true
                    
                case .failure(let error):
                    self.viewModel.error = String(localized: "Failed to package IPA: \(error.localizedDescription)")
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func importIpaToLibrary(_ file: FileItem) {
        isExtracting = true
        extractionProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let id = "FeatherManualDownload_\(UUID().uuidString)"
                
                let download = self.downloadManager.startArchive(from: file.url, id: id)
                
                DispatchQueue.main.async {
                    self.extractionProgress = 0.3
                }
                
                try self.downloadManager.handlePachageFile(url: file.url, dl: download)
                
                DispatchQueue.main.async {
                    self.isExtracting = false
                    self.viewModel.error = String(localized: "Successfully imported \(file.name) to Library")
                    self.viewModel.showingError = true
                }
            } catch {
                print("Import error: \(error)")
                DispatchQueue.main.async {
                    self.isExtracting = false
                    self.viewModel.error = String(localized: "Failed to import to Library: \(error.localizedDescription)")
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func presentQuickLook(for file: FileItem) {
        let previewController = QuickLookController.shared
        previewController.previewFile(file.url)
    }
    
    // MARK: - UI Helpers
    
    private func selectionBackground(for file: FileItem) -> some View {
        FileUIHelpers.selectionBackground(for: file, selectedItems: viewModel.selectedItems)
    }
    
    @ViewBuilder
    private func swipeActions(for file: FileItem) -> some View {
        FileUIHelpers.swipeActions(for: file, viewModel: viewModel)
    }
} 
