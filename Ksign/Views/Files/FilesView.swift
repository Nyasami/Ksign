//
//  FilesView.swift
//  Ksign
//
//  تم الإنشاء بواسطة Nagata Asami في 5/22/25.
//  تصميم محسّن ✨
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
    @Namespace private var _namespace
    
    @StateObject private var viewModel: FilesViewModel
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var searchText = ""

    @AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false

    @State private var plistFileURL: URL?
    @State private var hexEditorFileURL: URL?
    @State private var textEditorFileURL: URL?
    @State private var quickLookFileURL: URL?
    @State private var moveSingleFile: FileItem?
    @State private var shareItems: [Any] = []
    @State private var navigateToDirectoryURL: URL?
    
    // MARK: - المُهيّئات (Initializers)
    
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
    
    // MARK: - المحتوى الرئيسي (Main Content)
    
    private var filesBrowserContent: some View {
        ZStack {
            contentView
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "بحث عن ملف")
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
                    NBToolbarMenu(
                        systemImage: "arrow.up.arrow.down.circle",
                        style: .icon,
                        placement: .topBarTrailing
                    ) {
                        _sortActions()
                    }
                    if viewModel.isEditMode == .active {
                        ToolbarItem(placement: .principal) {
                            selectionCountLabel
                        }
                        ToolbarItemGroup(placement: .bottomBar) {
                            selectAllButton
                            Spacer()
                            moveButton
                            Spacer()
                            shareButton
                            Spacer()
                            deleteButton
                        }
                    }
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
        .sheet(item: $moveSingleFile) { item in
            FileExporterRepresentableView(
                urlsToExport: [item.url],
                asCopy: false,
                useLastLocation: _useLastExportLocation,
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
                useLastLocation: _useLastExportLocation,
                onCompletion: { _ in
                    viewModel.selectedItems.removeAll()
                    if viewModel.isEditMode == .active { viewModel.isEditMode = .inactive }
                
                    viewModel.loadFiles()
                }
            )
        }

        .fullScreenCover(item: $plistFileURL) { fileURL in
            PlistEditorView(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
        .fullScreenCover(item: $hexEditorFileURL) { fileURL in
            HexEditorView(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
        .fullScreenCover(item: $textEditorFileURL) { fileURL in
            TextEditorView(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
        .fullScreenCover(item: $quickLookFileURL) { fileURL in
            QuickLookPreview(fileURL: fileURL)
                .compatNavigationTransition(id: fileURL.absoluteString, ns: _namespace)
        }
    }
    
    // MARK: - عروض المحتوى (Content Views)
    
    @ViewBuilder
    private var contentView: some View {
        List {
            ForEach(filteredFiles) { file in
                FileRow(
                    file: file,
                    isSelected: viewModel.selectedItems.contains(file),
                    viewModel: viewModel,
                    plistFileURL: $plistFileURL,
                    hexEditorFileURL: $hexEditorFileURL,
                    textEditorFileURL: $textEditorFileURL,
                    quickLookFileURL: $quickLookFileURL,
                    shareItems: $shareItems,
                    moveFileItem: $moveSingleFile,
                    onExtractArchive: extractArchive,
                    onPackageApp: packageAppAsIPA,
                    onImportIpa: importIpaToLibrary,
                    onNavigateToDirectory: navigateToDirectory
                )
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(viewModel.selectedItems.contains(file) ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .swipeActions(edge: .trailing) {
                    swipeActions(for: file)
                }
                .compatMatchedTransitionSource(id: file.url.absoluteString, ns: _namespace)
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: filteredFiles)
        .environment(\.editMode, $viewModel.isEditMode)
        .navigationDestination(isPresented: Binding(
            get: { navigateToDirectoryURL != nil },
            set: { if !$0 { navigateToDirectoryURL = nil } }
        )) {
            if let url = navigateToDirectoryURL {
                FilesView(directoryURL: url)
            }
        }
        .overlay {
            if filteredFiles.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("لا توجد ملفات"), systemImage: "folder.fill.badge.questionmark")
                            .foregroundStyle(.secondary)
                    } description: {
                        Text(.localized("ابدأ باستيراد أول ملف لك."))
                    } actions: {
                        Button {
                            viewModel.showingImporter = true
                        } label: {
                            Label("استيراد ملفات", systemImage: "square.and.arrow.down")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - خصائص مساعدة (Helper Properties)
    
    private var navigationTitle: String {
        if let directoryURL = directoryURL {
            return directoryURL.lastPathComponent
        } else {
            return viewModel.currentDirectory.lastPathComponent
        }
    }
    
    private var selectionCountLabel: some View {
        Text(viewModel.selectedItems.isEmpty
             ? "اختر عناصر"
             : "تم اختيار \(viewModel.selectedItems.count)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(viewModel.selectedItems.isEmpty ? .secondary : .primary)
    }
    

    // MARK: - طرق الإعداد (Setup Methods)
    
    private func setupView() {
        viewModel.loadFiles()
    }
    
   
    
    // MARK: - عناصر شريط الأدوات (Toolbar Items)
    
    private var addButton: some View {
        Menu {
            Button {
                viewModel.showingImporter = true
            } label: {
                Label(String(localized: "استيراد ملفات"), systemImage: "square.and.arrow.down")
            }
            Button {
                UIAlertController.showAlertWithTextBox(
                    title: .localized("مجلد جديد"),
                    message: .localized("أدخل اسمًا للمجلد الجديد"),
                    textFieldPlaceholder: .localized("اسم المجلد"),
                    submit: .localized("إنشاء"),
                    cancel: .localized("إلغاء"),
                    onSubmit: { name in
                        viewModel.createNewFolder(name: name)
                    }
                )
            } label: {
                Label(String(localized: "مجلد جديد"), systemImage: "folder.badge.plus")
            }
            Button {
                UIAlertController.showAlertWithTextBox(
                    title: .localized("ملف نصي جديد"),
                    message: .localized("أدخل اسمًا للملف النصي الجديد"),
                    textFieldPlaceholder: .localized("اسم الملف النصي"),
                    textFieldText: "بدون اسم.txt",
                    submit: .localized("إنشاء"),
                    cancel: .localized("إلغاء"),
                    onSubmit: { name in
                       viewModel.createNewTextFile(name: name)
                    }
                )
            } label: {
                Label(String(localized: "ملف نصي جديد"), systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 20))
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
            Text(viewModel.isEditMode == .active ? String(localized: "تم") : String(localized: "تعديل"))
                .fontWeight(viewModel.isEditMode == .active ? .semibold : .regular)
        }
    }
    
    private var selectAllButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if viewModel.selectedItems.isEmpty {
                    for file in viewModel.files {
                        viewModel.selectedItems.insert(file)
                    }
                } else {
                    viewModel.selectedItems.removeAll()
                }
            }
        } label: {
            Image(systemName: viewModel.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
                .font(.system(size: 18))
        }
    }
    
    private var moveButton: some View {
        Button {
            viewModel.showDirectoryPicker = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "folder")
                    .font(.system(size: 18))
                Text("نقل").font(.caption2)
            }
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var shareButton: some View {
        Button {
            if !viewModel.selectedItems.isEmpty {
                let urls = viewModel.selectedItems.map { $0.url }
                shareItems = urls
                UIActivityViewController.show(activityItems: shareItems)
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                Text("مشاركة").font(.caption2)
            }
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            withAnimation {
                viewModel.deleteSelectedItems()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                Text("حذف").font(.caption2)
            }
        }
        .tint(.red)
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    // MARK: - الإجراءات (Actions)
    
    private func navigateToDirectory(_ url: URL) {
        navigateToDirectoryURL = url
    }
    

    
    // MARK: - عمليات الملفات (File Operations)
    
    private func extractArchive(_ file: FileItem) {
        guard file.isArchive else { return }
        
        let extractItem = ExtractManager.shared.start(fileName: file.name)
        ExtractionService.extractArchive(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    ExtractManager.shared.updateProgress(for: extractItem, progress: progress)
                }
            }
        ) { result in
            DispatchQueue.main.async {
                
                switch result {
                case .success:
                    withAnimation {
                        self.viewModel.loadFiles()
                    }
                    
                case .failure:
                    UIAlertController.showAlertWithOk(title: .localized("خطأ"), message: .localized("عذرًا، حدث خطأ ما أثناء استخراج الملف. \nربما جرّب تبديل مكتبة الاستخراج من الإعدادات؟"))
                }
                ExtractManager.shared.finish(item: extractItem)
            }
        }
    }
    
    private func packageAppAsIPA(_ file: FileItem) {
        guard file.isAppDirectory else { return }
        
        let extractItem = ExtractManager.shared.start(fileName: file.name)
        ExtractionService.packageAppAsIPA(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    ExtractManager.shared.updateProgress(for: extractItem, progress: progress)
                }
            }
        ) { result in
            DispatchQueue.main.async {
                
                switch result {
                case .success(let ipaFileName):
                    self.viewModel.loadFiles()
                    UIAlertController.showAlertWithOk(title: .localized("نجاح"), message: .localized("تم تحويل \(file.name) إلى \(ipaFileName) بنجاح"))
                case .failure(let error):
                    UIAlertController.showAlertWithOk(title: .localized("خطأ"), message: .localized("فشل تحويل الملف إلى IPA: \(error.localizedDescription)"))
                }
                ExtractManager.shared.finish(item: extractItem)
            }
        }
    }
    
    private func importIpaToLibrary(_ file: FileItem) {
        let id = "FeatherManualDownload_\(UUID().uuidString)"
        let download = self.downloadManager.startArchive(from: file.url, id: id)
        downloadManager.handlePachageFile(url: file.url, dl: download) { err in
            DispatchQueue.main.async {
                if let error = err {
                    UIAlertController.showAlertWithOk(title: .localized("خطأ"), message: .localized("عذرًا، حدث خطأ ما أثناء استخراج الملف. \nربما جرّب تبديل مكتبة الاستخراج من الإعدادات؟"))
                } else {
                }
                if let index = DownloadManager.shared.getDownloadIndex(by: download.id) {
                    DownloadManager.shared.downloads.remove(at: index)
                }
            }
        }
    }

    
    // MARK: - أدوات مساعدة للواجهة (UI Helpers)
    
    @ViewBuilder
    private func swipeActions(for file: FileItem) -> some View {
        FileUIHelpers.swipeActions(for: file, viewModel: viewModel)
    }

    @ViewBuilder
    private func _sortActions() -> some View {
        Section(.localized("ترتيب حسب")) {
            ForEach(FilesViewModel.SortOption.allCases, id: \.displayName) { opt in
                _sortButton(for: opt)
            }
        }
    }

    private func _sortButton(for option: FilesViewModel.SortOption) -> some View {
        Button {
            if viewModel.sortOption == option {
                viewModel.updateSort(option: option, ascending: !viewModel.sortAscending)
            } else {
                viewModel.updateSort(option: option, ascending: true)
            }
        } label: {
            HStack {
                Text(option.displayName)
                Spacer()
                if viewModel.sortOption == option {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.accent)
                }
            }
        }
    }
}
