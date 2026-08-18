//
//  FilesView.swift
//  Ksign
//
//  Redesigned Store UI
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import NimbleViews

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

// MARK: - Main Files View

struct FilesView: View {

    let directoryURL: URL?
    let isRootView: Bool

    @Namespace private var _namespace

    @StateObject private var viewModel: FilesViewModel
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var searchText = ""
    @State private var selectedTab: StoreTab = .home

    @AppStorage("Feather.useLastExportLocation")
    private var _useLastExportLocation: Bool = false

    @State private var plistFileURL: URL?
    @State private var hexEditorFileURL: URL?
    @State private var textEditorFileURL: URL?
    @State private var quickLookFileURL: URL?

    @State private var moveSingleFile: FileItem?
    @State private var shareItems: [Any] = []
    @State private var navigateToDirectoryURL: URL?

    // MARK: - Initializers

    init() {
        self.directoryURL = nil
        self.isRootView = true
        self._viewModel = StateObject(
            wrappedValue: FilesViewModel()
        )
    }

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.isRootView = false
        self._viewModel = StateObject(
            wrappedValue: FilesViewModel(directory: directoryURL)
        )
    }

    // MARK: - Computed Properties

    private var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return viewModel.files
        }

        return viewModel.files.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var applicationFiles: [FileItem] {
        filteredFiles.filter { file in
            file.isAppDirectory ||
            file.name.lowercased().hasSuffix(".ipa") ||
            file.name.lowercased().hasSuffix(".app")
        }
    }

    private var displayFiles: [FileItem] {
        applicationFiles.isEmpty ? filteredFiles : applicationFiles
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isRootView {
                NavigationStack {
                    storeRootView
                }
                .accentColor(.black)
            } else {
                NavigationStack {
                    fileBrowserView
                }
                .accentColor(.black)
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

    // MARK: - Store Root

    private var storeRootView: some View {
        ZStack {
            StoreBackground()

            VStack(spacing: 0) {
                storeHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {

                        if selectedTab == .home {
                            homeContent
                        } else if selectedTab == .apps {
                            applicationsContent
                        } else {
                            sourcesContent
                        }
                    }
                    .padding(.bottom, 105)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StoreTabBar(selection: $selectedTab)
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

                    if viewModel.isEditMode == .active {
                        viewModel.isEditMode = .inactive
                    }

                    viewModel.loadFiles()
                }
            )
        }
        .fullScreenCover(item: $plistFileURL) { fileURL in
            PlistEditorView(fileURL: fileURL)
                .compatNavigationTransition(
                    id: fileURL.absoluteString,
                    ns: _namespace
                )
        }
        .fullScreenCover(item: $hexEditorFileURL) { fileURL in
            HexEditorView(fileURL: fileURL)
                .compatNavigationTransition(
                    id: fileURL.absoluteString,
                    ns: _namespace
                )
        }
        .fullScreenCover(item: $textEditorFileURL) { fileURL in
            TextEditorView(fileURL: fileURL)
                .compatNavigationTransition(
                    id: fileURL.absoluteString,
                    ns: _namespace
                )
        }
        .fullScreenCover(item: $quickLookFileURL) { fileURL in
            QuickLookPreview(fileURL: fileURL)
                .compatNavigationTransition(
                    id: fileURL.absoluteString,
                    ns: _namespace
                )
        }
    }

    // MARK: - Header

    private var storeHeader: some View {
        HStack(spacing: 10) {

            Spacer()

            Image(systemName: "apple.logo")
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(.blue)

            Text("ONES")
                .font(
                    .system(
                        size: 28,
                        weight: .heavy,
                        design: .rounded
                    )
                )
                .foregroundStyle(.black)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
    }

    // MARK: - Home Content

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 24) {

            StoreHeroCard {
                viewModel.showingImporter = true
            }

            StoreSectionHeader(
                title: "تطبيقات مميزة",
                action: {
                    withAnimation(.spring(response: 0.35)) {
                        selectedTab = .apps
                    }
                }
            )

            if displayFiles.isEmpty {
                EmptyStoreCard {
                    viewModel.showingImporter = true
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(displayFiles.prefix(5))) { file in
                        StoreAppCard(
                            file: file,
                            installAction: {
                                install(file)
                            },
                            openAction: {
                                openFile(file)
                            }
                        )
                    }
                }
            }

            StoreSectionHeader(
                title: "الأدوات",
                action: {
                    withAnimation(.spring(response: 0.35)) {
                        selectedTab = .sources
                    }
                }
            )

            toolsGrid
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    // MARK: - Applications

    private var applicationsContent: some View {
        VStack(alignment: .leading, spacing: 18) {

            HStack {
                Text("التطبيقات")
                    .font(.system(size: 29, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    viewModel.showingImporter = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(
                            color: .black.opacity(0.08),
                            radius: 10,
                            y: 4
                        )
                }
            }

            SearchBar(text: $searchText)

            if displayFiles.isEmpty {
                EmptyStoreCard {
                    viewModel.showingImporter = true
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(displayFiles) { file in
                        StoreAppCard(
                            file: file,
                            installAction: {
                                install(file)
                            },
                            openAction: {
                                openFile(file)
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }

    // MARK: - Sources

    private var sourcesContent: some View {
        VStack(alignment: .leading, spacing: 18) {

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("المصادر")
                        .font(.system(size: 29, weight: .bold))

                    Text(
                        directoryURL?.lastPathComponent
                        ?? viewModel.currentDirectory.lastPathComponent
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                addButton
            }

            SearchBar(text: $searchText)

            fileList
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }

    // MARK: - Tools

    private var toolsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {

            ToolCard(
                title: "استيراد",
                subtitle: "إضافة ملفات",
                icon: "square.and.arrow.down"
            ) {
                viewModel.showingImporter = true
            }

            ToolCard(
                title: "مجلد جديد",
                subtitle: "تنظيم الملفات",
                icon: "folder.badge.plus"
            ) {
                createFolder()
            }

            ToolCard(
                title: "ملف نصي",
                subtitle: "إنشاء ملف",
                icon: "doc.badge.plus"
            ) {
                createTextFile()
            }

            ToolCard(
                title: "تحديث",
                subtitle: "إعادة تحميل",
                icon: "arrow.clockwise"
            ) {
                withAnimation {
                    viewModel.loadFiles()
                }
            }
        }
    }

    // MARK: - File Browser

    private var fileBrowserView: some View {
        ZStack {
            StoreBackground()

            contentView
                .navigationTitle(navigationTitle)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(
                        displayMode: .always
                    )
                )
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        addButton
                        editButton
                    }

                    NBToolbarMenu(
                        systemImage: "line.3.horizontal.decrease",
                        style: .icon,
                        placement: .topBarTrailing
                    ) {
                        _sortActions()
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
                urlsToExport: Array(
                    viewModel.selectedItems.map { $0.url }
                ),
                asCopy: false,
                useLastLocation: _useLastExportLocation,
                onCompletion: { _ in
                    viewModel.selectedItems.removeAll()

                    if viewModel.isEditMode == .active {
                        viewModel.isEditMode = .inactive
                    }

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
        .fullScreenCover(item: $textEditorFileURL) { fileURL in
            TextEditorView(fileURL: fileURL)
        }
        .fullScreenCover(item: $quickLookFileURL) { fileURL in
            QuickLookPreview(fileURL: fileURL)
        }
    }

    // MARK: - Original File List

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
                .swipeActions(edge: .trailing) {
                    swipeActions(for: file)
                }
                .compatMatchedTransitionSource(
                    id: file.url.absoluteString,
                    ns: _namespace
                )
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .environment(
            \.editMode,
            $viewModel.isEditMode
        )
        .navigationDestination(
            isPresented: Binding(
                get: {
                    navigateToDirectoryURL != nil
                },
                set: {
                    if !$0 {
                        navigateToDirectoryURL = nil
                    }
                }
            )
        ) {
            if let url = navigateToDirectoryURL {
                FilesView(directoryURL: url)
            }
        }
        .overlay {
            if filteredFiles.isEmpty {
                ContentUnavailableView {
                    Label(
                        "لا توجد ملفات",
                        systemImage: "folder"
                    )
                } description: {
                    Text("ابدأ بإضافة ملف جديد إلى هذا المجلد.")
                } actions: {
                    Button {
                        viewModel.showingImporter = true
                    } label: {
                        Text("استيراد ملفات")
                            .bg()
                    }
                }
            }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let directoryURL = directoryURL {
            return directoryURL.lastPathComponent
        }

        return viewModel.currentDirectory.lastPathComponent
    }

    // MARK: - Setup

    private func setupView() {
        viewModel.loadFiles()
    }

    // MARK: - Add

    private var addButton: some View {
        Menu {

            Button {
                viewModel.showingImporter = true
            } label: {
                Label(
                    "استيراد ملفات",
                    systemImage: "square.and.arrow.down"
                )
            }

            Button {
                createFolder()
            } label: {
                Label(
                    "مجلد جديد",
                    systemImage: "folder.badge.plus"
                )
            }

            Button {
                createTextFile()
            } label: {
                Label(
                    "ملف نصي جديد",
                    systemImage: "doc.badge.plus"
                )
            }

        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }

    private func createFolder() {
        UIAlertController.showAlertWithTextBox(
            title: .localized("New Folder"),
            message: .localized("Enter a name for the new folder"),
            textFieldPlaceholder: .localized("Folder name"),
            submit: .localized("Create"),
            cancel: .localized("Cancel"),
            onSubmit: { name in
                viewModel.createNewFolder(name: name)
            }
        )
    }

    private func createTextFile() {
        UIAlertController.showAlertWithTextBox(
            title: .localized("New Text File"),
            message: .localized("Enter a name for the new text file"),
            textFieldPlaceholder: .localized("Text file name"),
            textFieldText: "Unnamed.txt",
            submit: .localized("Create"),
            cancel: .localized("Cancel"),
            onSubmit: { name in
                viewModel.createNewTextFile(name: name)
            }
        )
    }

    // MARK: - Edit

    private var editButton: some View {
        Button {
            withAnimation(
                .spring(
                    response: 0.35,
                    dampingFraction: 0.9
                )
            ) {
                viewModel.isEditMode =
                    viewModel.isEditMode == .active
                    ? .inactive
                    : .active

                if viewModel.isEditMode == .inactive {
                    viewModel.selectedItems.removeAll()
                }
            }
        } label: {
            Text(
                viewModel.isEditMode == .active
                ? "تم"
                : "تعديل"
            )
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
            Image(
                systemName:
                    viewModel.selectedItems.isEmpty
                    ? "checklist.checked"
                    : "checklist.unchecked"
            )
        }
    }

    private var moveButton: some View {
        Button {
            viewModel.showDirectoryPicker = true
        } label: {
            Label("نقل", systemImage: "folder")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }

    private var shareButton: some View {
        Button {
            if !viewModel.selectedItems.isEmpty {
                let urls = viewModel.selectedItems.map {
                    $0.url
                }

                shareItems = urls

                UIActivityViewController.show(
                    activityItems: shareItems
                )
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
        }
        .tint(.red)
        .disabled(viewModel.selectedItems.isEmpty)
    }

    // MARK: - Store Actions

    private func install(_ file: FileItem) {

        let lowerName = file.name.lowercased()

        if lowerName.hasSuffix(".ipa") {
            importIpaToLibrary(file)
            return
        }

        if file.isAppDirectory {
            packageAppAsIPA(file)
            return
        }

        openFile(file)
    }

    private func openFile(_ file: FileItem) {

        if file.isAppDirectory {
            navigateToDirectory(file.url)
            return
        }

        let lowerName = file.name.lowercased()

        if lowerName.hasSuffix(".plist") {
            plistFileURL = file.url
        } else if lowerName.hasSuffix(".txt") ||
                    lowerName.hasSuffix(".json") ||
                    lowerName.hasSuffix(".xml") {
            textEditorFileURL = file.url
        } else {
            quickLookFileURL = file.url
        }
    }

    // MARK: - Navigation

    private func navigateToDirectory(_ url: URL) {
        navigateToDirectoryURL = url
    }

    // MARK: - File Operations

    private func extractArchive(_ file: FileItem) {

        guard file.isArchive else {
            return
        }

        let extractItem =
            ExtractManager.shared.start(
                fileName: file.name
            )

        ExtractionService.extractArchive(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in

                DispatchQueue.main.async {
                    ExtractManager.shared.updateProgress(
                        for: extractItem,
                        progress: progress
                    )
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
                    UIAlertController.showAlertWithOk(
                        title: .localized("Error"),
                        message: .localized(
                            """
                            Whoops!, something went wrong when extracting the file.
                            Maybe try switching the extraction library in the settings?
                            """
                        )
                    )
                }

                ExtractManager.shared.finish(
                    item: extractItem
                )
            }
        }
    }

    private func packageAppAsIPA(_ file: FileItem) {

        guard file.isAppDirectory else {
            return
        }

        let extractItem =
            ExtractManager.shared.start(
                fileName: file.name
            )

        ExtractionService.packageAppAsIPA(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in

                DispatchQueue.main.async {
                    ExtractManager.shared.updateProgress(
                        for: extractItem,
                        progress: progress
                    )
                }

            }
        ) { result in

            DispatchQueue.main.async {

                switch result {

                case .success(let ipaFileName):

                    self.viewModel.loadFiles()

                    UIAlertController.showAlertWithOk(
                        title: .localized("Success"),
                        message: .localized(
                            "Successfully packaged \(file.name) as \(ipaFileName)"
                        )
                    )

                case .failure(let error):

                    UIAlertController.showAlertWithOk(
                        title: .localized("Error"),
                        message: .localized(
                            "Failed to package IPA: \(error.localizedDescription)"
                        )
                    )
                }

                ExtractManager.shared.finish(
                    item: extractItem
                )
            }
        }
    }

    private func importIpaToLibrary(_ file: FileItem) {

        let id =
            "FeatherManualDownload_\(UUID().uuidString)"

        let download =
            self.downloadManager.startArchive(
                from: file.url,
                id: id
            )

        downloadManager.handlePachageFile(
            url: file.url,
            dl: download
        ) { err in

            DispatchQueue.main.async {

                if let error = err {

                    UIAlertController.showAlertWithOk(
                        title: .localized("Error"),
                        message: .localized(
                            "Whoops!, something went wrong when extracting the file. Maybe try switching the extraction library in the settings?"
                        )
                    )

                    print(
                        "IPA import error: \(error.localizedDescription)"
                    )
                }

                if let index =
                    DownloadManager.shared.getDownloadIndex(
                        by: download.id
                    ) {

                    DownloadManager.shared.downloads.remove(
                        at: index
                    )
                }
            }
        }
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func swipeActions(
        for file: FileItem
    ) -> some View {
        FileUIHelpers.swipeActions(
            for: file,
            viewModel: viewModel
        )
    }

    // MARK: - Sort

    @ViewBuilder
    private func _sortActions() -> some View {

        Section(.localized("Filter by")) {

            ForEach(
                FilesViewModel.SortOption.allCases,
                id: \.displayName
            ) { opt in

                _sortButton(
                    for: opt
                )
            }
        }
    }

    private func _sortButton(
        for option: FilesViewModel.SortOption
    ) -> some View {

        Button {

            if viewModel.sortOption == option {

                viewModel.updateSort(
                    option: option,
                    ascending: !viewModel.sortAscending
                )

            } else {

                viewModel.updateSort(
                    option: option,
                    ascending: true
                )
            }

        } label: {

            HStack {

                Text(option.displayName)

                Spacer()

                if viewModel.sortOption == option {
                    Image(
                        systemName:
                            viewModel.sortAscending
                            ? "chevron.up"
                            : "chevron.down"
                    )
                }
            }
        }
    }
}

// MARK: - Store Tab

private enum StoreTab: CaseIterable {
    case home
    case apps
    case sources

    var title: String {
        switch self {
        case .home:
            return "الرئيسية"
        case .apps:
            return "التطبيقات"
        case .sources:
            return "المصادر"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .apps:
            return "square.grid.2x2.fill"
        case .sources:
            return "folder.fill"
        }
    }
}

// MARK: - Background

private struct StoreBackground: View {

    var body: some View {
        Color(
            red: 0.95,
            green: 0.93,
            blue: 0.88
        )
        .ignoresSafeArea()
    }
}

// MARK: - Hero

private struct StoreHeroCard: View {

    let importAction: () -> Void

    var body: some View {

        VStack(spacing: 0) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 9
                ) {

                    HStack(spacing: 8) {

                        Text("ONES")
                            .font(
                                .system(
                                    size: 34,
                                    weight: .black,
                                    design: .rounded
                                )
                            )

                        Text("متجر بلس")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)
                            .padding(
                                .horizontal,
                                9
                            )
                            .padding(
                                .vertical,
                                5
                            )
                            .background(
                                Color(
                                    red: 0.87,
                                    green: 0.60,
                                    blue: 0.12
                                )
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 8
                                )
                            )
                    }

                    Text("كل ما تحتاجه في متجر واحد")
                        .font(
                            .system(
                                size: 21,
                                weight: .bold
                            )
                        )

                    Text(
                        "تطبيقات معدلة وأكثر من 100+ تطبيق وألعاب آمنة، مراسلات مزدوجة، والمزيد!"
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .black.opacity(0.65)
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    Button {
                        importAction()
                    } label: {
                        HStack(spacing: 7) {
                            Image(
                                systemName:
                                    "square.and.arrow.down"
                            )

                            Text("إضافة تطبيق")
                        }
                        .font(
                            .system(
                                size: 14,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                        .padding(
                            .horizontal,
                            15
                        )
                        .padding(
                            .vertical,
                            10
                        )
                        .background(
                            Color(
                                red: 0.88,
                                green: 0.61,
                                blue: 0.15
                            )
                        )
                        .clipShape(
                            Capsule()
                        )
                    }
                }

                Spacer()

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 24
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(
                                    red: 1.0,
                                    green: 0.75,
                                    blue: 0.17
                                ),
                                Color(
                                    red: 0.91,
                                    green: 0.51,
                                    blue: 0.12
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: 90,
                        height: 90
                    )

                    Image(systemName: "shippingbox.fill")
                        .font(
                            .system(
                                size: 44,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)
                }
            }
            .padding(22)

            HStack(spacing: 7) {

                HeroPill(
                    title: "تطبيقات مميزة"
                )

                HeroPill(
                    title: "مراسلات مزدوجة"
                )

                HeroPill(
                    title: "ألعاب"
                )

                HeroPill(
                    title: "تحميل سهل"
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 17)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(
                        red: 1.0,
                        green: 0.94,
                        blue: 0.84
                    ),
                    Color(
                        red: 1.0,
                        green: 0.89,
                        blue: 0.74
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.65),
                lineWidth: 1
            )
        )
        .shadow(
            color: .black.opacity(0.07),
            radius: 18,
            y: 8
        )
    }
}

// MARK: - Hero Pill

private struct HeroPill: View {

    let title: String

    var body: some View {

        HStack(spacing: 4) {

            Image(
                systemName: "checkmark.circle.fill"
            )
            .font(.system(size: 9))
            .foregroundStyle(
                Color(
                    red: 0.08,
                    green: 0.55,
                    blue: 0.58
                )
            )

            Text(title)
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
        }
        .foregroundStyle(
            .black.opacity(0.65)
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            6
        )
        .background(
            .white.opacity(0.72)
        )
        .clipShape(
            Capsule()
        )
    }
}

// MARK: - Section Header

private struct StoreSectionHeader: View {

    let title: String
    let action: () -> Void

    var body: some View {

        HStack {

            Text(title)
                .font(
                    .system(
                        size: 24,
                        weight: .bold
                    )
                )
                .foregroundStyle(.black)

            Spacer()

            Button("عرض الكل") {
                action()
            }
            .font(
                .system(
                    size: 13,
                    weight: .bold
                )
            )
            .foregroundStyle(
                Color(
                    red: 0.78,
                    green: 0.48,
                    blue: 0.05
                )
            )
        }
    }
}

// MARK: - App Card

private struct StoreAppCard: View {

    let file: FileItem
    let installAction: () -> Void
    let openAction: () -> Void

    private var displayName: String {
        let value = file.name

        if value.lowercased().hasSuffix(".ipa") {
            return String(
                value.dropLast(4)
            )
        }

        if value.lowercased().hasSuffix(".app") {
            return String(
                value.dropLast(4)
            )
        }

        return value
    }

    private var iconName: String {

        let name = displayName.lowercased()

        if name.contains("weather") {
            return "cloud.sun.fill"
        }

        if name.contains("music") ||
            name.contains("sound") {
            return "waveform"
        }

        if name.contains("server") {
            return "server.rack"
        }

        if name.contains("photo") {
            return "photo.fill"
        }

        if name.contains("game") {
            return "gamecontroller.fill"
        }

        return "app.fill"
    }

    var body: some View {

        HStack(spacing: 14) {

            Button {
                openAction()
            } label: {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(
                                    red: 0.98,
                                    green: 0.75,
                                    blue: 0.34
                                ),
                                Color(
                                    red: 0.92,
                                    green: 0.51,
                                    blue: 0.22
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    Image(systemName: iconName)
                        .font(
                            .system(
                                size: 30,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                }
                .frame(
                    width: 70,
                    height: 70
                )
            }
            .buttonStyle(.plain)

            VStack(
                alignment: .leading,
                spacing: 7
            ) {

                Text(displayName)
                    .font(
                        .system(
                            size: 18,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Text("التطبيقات")
                    .font(
                        .system(
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.84,
                            green: 0.57,
                            blue: 0.10
                        )
                    )

                Text("متوفر الآن • تحميل سريع")
                    .font(
                        .system(
                            size: 11,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            Button {
                installAction()
            } label: {

                Text(
                    file.name
                        .lowercased()
                        .hasSuffix(".ipa")
                        ? "تثبيت"
                        : "فتح"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .vertical,
                    10
                )
                .background(
                    Color(
                        red: 0.90,
                        green: 0.64,
                        blue: 0.19
                    )
                )
                .clipShape(
                    Capsule()
                )
            }
        }
        .padding(13)
        .background(.white)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.075),
            radius: 13,
            y: 5
        )
    }
}

// MARK: - Tool Card

private struct ToolCard: View {

    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {

        Button {
            action()
        } label: {

            HStack(spacing: 12) {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 21,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 0.86,
                            green: 0.58,
                            blue: 0.11
                        )
                    )
                    .frame(
                        width: 43,
                        height: 43
                    )
                    .background(
                        Color(
                            red: 1.0,
                            green: 0.94,
                            blue: 0.79
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 13
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text(title)
                        .font(
                            .system(
                                size: 14,
                                weight: .bold
                            )
                        )

                    Text(subtitle)
                        .font(
                            .system(
                                size: 11,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .foregroundStyle(.black)
            .padding(13)
            .background(.white)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 19,
                    style: .continuous
                )
            )
            .shadow(
                color: .black.opacity(0.055),
                radius: 10,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Store

private struct EmptyStoreCard: View {

    let importAction: () -> Void

    var body: some View {

        VStack(spacing: 13) {

            Image(systemName: "square.grid.2x2")
                .font(
                    .system(
                        size: 35,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color(
                        red: 0.86,
                        green: 0.58,
                        blue: 0.12
                    )
                )

            Text("لا توجد تطبيقات بعد")
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )

            Text(
                "أضف ملف IPA أو تطبيق إلى مكتبتك وسيظهر هنا."
            )
            .font(
                .system(
                    size: 13,
                    weight: .medium
                )
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                importAction()
            } label: {

                Text("استيراد تطبيق")
                    .font(
                        .system(
                            size: 14,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                    .padding(
                        .horizontal,
                        18
                    )
                    .padding(
                        .vertical,
                        11
                    )
                    .background(
                        Color(
                            red: 0.88,
                            green: 0.60,
                            blue: 0.13
                        )
                    )
                    .clipShape(Capsule())
            }
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(30)
        .background(.white)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
        )
    }
}

// MARK: - Search Bar

private struct SearchBar: View {

    @Binding var text: String

    var body: some View {

        HStack(spacing: 9) {

            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "بحث عن تطبيق أو ملف",
                text: $text
            )
            .font(
                .system(
                    size: 14,
                    weight: .medium
                )
            )

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(
            .horizontal,
            15
        )
        .frame(height: 48)
        .background(.white)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.045),
            radius: 9,
            y: 3
        )
    }
}

// MARK: - Bottom Tab Bar

private struct StoreTabBar: View {

    @Binding var selection: StoreTab

    var body: some View {

        HStack(spacing: 0) {

            tab(
                .sources
            )

            tab(
                .apps
            )

            tab(
                .home
            )
        }
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            8
        )
        .background(.ultraThinMaterial)
        .clipShape(
            Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    .white.opacity(0.9),
                    lineWidth: 1
                )
        )
        .shadow(
            color: .black.opacity(0.14),
            radius: 18,
            y: 7
        )
        .padding(
            .horizontal,
            28
        )
        .padding(
            .bottom,
            8
        )
    }

    private func tab(
        _ tab: StoreTab
    ) -> some View {

        Button {

            withAnimation(
                .spring(
                    response: 0.35,
                    dampingFraction: 0.82
                )
            ) {
                selection = tab
            }

        } label: {

            VStack(spacing: 4) {

                Image(
                    systemName:
                        tab.icon
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )

                Text(tab.title)
                    .font(
                        .system(
                            size: 10,
                            weight: .bold
                        )
                    )
            }
            .foregroundStyle(
                selection == tab
                ? Color(
                    red: 0.88,
                    green: 0.62,
                    blue: 0.15
                )
                : .black
            )
            .frame(
                maxWidth: .infinity
            )
            .frame(height: 51)
            .background {

                if selection == tab {
                    Capsule()
                        .fill(
                            Color.white.opacity(0.75)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}
