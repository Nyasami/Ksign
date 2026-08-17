//
//  SourceAppsView.swift
//  Ksign
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

struct SourceAppsView: View {
    
    // MARK: - Sort
    
    enum SortOption: String, CaseIterable {
        case `default` = "default"
        case name
        case date
        
        var displayName: String {
            switch self {
            case .default:
                return "الافتراضي"
            case .name:
                return "الاسم"
            case .date:
                return "الأحدث"
            }
        }
    }
    
    // MARK: - State
    
    @AppStorage("Feather.sortOptionRawValue")
    private var _sortOptionRawValue: String = SortOption.default.rawValue
    
    @AppStorage("Feather.sortAscending")
    private var _sortAscending: Bool = true
    
    @State private var _sortOption: SortOption = .default
    @State private var _searchText = ""
    @State private var _selectedRoute: SourceAppRoute?
    @State private var _selectedCategory = "الكل"
    @State private var _sources: [ASRepository]?
    @State private var _isLoading = true
    @State private var _hasLoadedOnce = false
    
    var fromAppStore: Bool = false
    
    let object: [AltSource]
    
    @ObservedObject var viewModel: SourcesViewModel
    
    // MARK: - Computed
    
    private var _navigationTitle: String {
        if fromAppStore {
            return "المتجر"
        } else if object.count == 1 {
            return object.first?.name ?? "المتجر"
        } else {
            return "\(object.count) مصادر"
        }
    }
    
    private var _allApps: [(source: ASRepository, app: ASRepository.App)] {
        guard let sources = _sources else {
            return []
        }
        
        return sources.flatMap { source in
            source.apps.map {
                (source: source, app: $0)
            }
        }
    }
    
    private var _filteredApps: [(source: ASRepository, app: ASRepository.App)] {
        var apps = _allApps
        
        if !_searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = _searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            apps = apps.filter { item in
                item.app.name?.localizedCaseInsensitiveContains(query) == true ||
                item.app.subtitle?.localizedCaseInsensitiveContains(query) == true ||
                item.app.description?.localizedCaseInsensitiveContains(query) == true ||
                item.app.localizedDescription?.localizedCaseInsensitiveContains(query) == true
            }
        }
        
        if _selectedCategory != "الكل" {
            apps = apps.filter { item in
                _categoryName(for: item.app) == _selectedCategory
            }
        }
        
        switch _sortOption {
        case .default:
            break
            
        case .name:
            apps.sort {
                let lhs = $0.app.name ?? ""
                let rhs = $1.app.name ?? ""
                
                let result = lhs.localizedCaseInsensitiveCompare(rhs)
                
                return _sortAscending
                ? result == .orderedAscending
                : result == .orderedDescending
            }
            
        case .date:
            apps.sort {
                let lhs = $0.app.currentDate?.date ?? .distantPast
                let rhs = $1.app.currentDate?.date ?? .distantPast
                
                return _sortAscending
                ? lhs > rhs
                : lhs < rhs
            }
        }
        
        if _sortOption == .default && !_sortAscending {
            apps.reverse()
        }
        
        return apps
    }
    
    private var _categories: [String] {
        var result: [String] = ["الكل"]
        
        for item in _allApps {
            let category = _categoryName(for: item.app)
            
            if category != "أخرى" && !result.contains(category) {
                result.append(category)
            }
        }
        
        if _allApps.contains(where: {
            _categoryName(for: $0.app) == "أخرى"
        }) {
            result.append("أخرى")
        }
        
        return result
    }
    
    private var _bannerNews: [ASRepository.NewsItem] {
        guard let firstSource = _sources?.first,
              let news = firstSource.news else {
            return []
        }
        
        return news
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if _isLoading {
                _loadingView
            } else {
                _storeContent
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .navigationTitle(_navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $_searchText,
            placement: .platform(),
            prompt: "ابحث عن تطبيق"
        )
        .toolbar {
            
            if fromAppStore {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SourcesView()
                    } label: {
                        Text("المصادر")
                    }
                }
            }
            
            ToolbarItemGroup(placement: .topBarTrailing) {
                
                Button {
                    Task {
                        await viewModel.fetchSources(
                            _allSources,
                            refresh: true
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("تحديث")
                
                Menu {
                    _sortMenu
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("ترتيب")
            }
        }
        .toolbarTitleMenu {
            if let firstSource = _sources?.first,
               _sources?.count == 1 {
                
                if let website = firstSource.website {
                    Button("زيارة الموقع", systemImage: "globe") {
                        UIApplication.open(website)
                    }
                }
                
                if let patreon = firstSource.patreonURL {
                    Button("دعم المصدر", systemImage: "heart") {
                        UIApplication.open(patreon)
                    }
                }
                
                Divider()
            }
            
            Button("نسخ رابط المصدر", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = object.compactMap {
                    $0.sourceURL?.absoluteString
                }.joined(separator: "\n")
                
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            }
        }
        .onAppear {
            _sortOption = SortOption(
                rawValue: _sortOptionRawValue
            ) ?? .default
            
            if !_hasLoadedOnce && viewModel.isFinished {
                _load()
                _hasLoadedOnce = true
            }
        }
        .onChange(of: viewModel.isFinished) { _ in
            _load()
        }
        .onChange(of: _sortOption) { newValue in
            _sortOptionRawValue = newValue.rawValue
        }
        .navigationDestinationIfAvailable(item: $_selectedRoute) { route in
            SourceAppsDetailView(
                source: route.source,
                app: route.app
            )
        }
    }
    
    // MARK: - Store Content
    
    private var _storeContent: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 22
            ) {
                
                // MARK: Banner
                
                if !_bannerNews.isEmpty {
                    _bannerSection
                } else {
                    _welcomeBanner
                }
                
                // MARK: Categories
                
                if _categories.count > 1 {
                    _categoriesSection
                }
                
                // MARK: Apps
                
                _appsSection
            }
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Banner
    
    private var _bannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("المميز")
                .font(.title2.bold())
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(
                        Array(_bannerNews.enumerated()),
                        id: \.offset
                    ) { _, news in
                        _newsCard(news)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var _welcomeBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("مرحباً بك 👋")
                        .font(.title.bold())
                    
                    Text("اكتشف أفضل التطبيقات من مصادرك")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 38))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.background)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }
    
    private func _newsCard(_ news: ASRepository.NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = news.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            
                    default:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 310, height: 155)
                .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 310, height: 155)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                    }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(news.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let caption = news.caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(13)
        }
        .frame(width: 310, alignment: .leading)
        .background(.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .strokeBorder(.quaternary, lineWidth: 1)
        }
        .shadow(
            color: .black.opacity(0.05),
            radius: 10,
            y: 4
        )
    }
    
    // MARK: - Categories
    
    private var _categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الفئات")
                .font(.title2.bold())
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal) {
                LazyHStack(spacing: 9) {
                    ForEach(_categories, id: \.self) { category in
                        Button {
                            withAnimation(.snappy) {
                                _selectedCategory = category
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: _categoryIcon(category))
                                
                                Text(category)
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .foregroundStyle(
                                _selectedCategory == category
                                ? Color.white
                                : Color.primary
                            )
                            .background {
                                Capsule()
                                    .fill(
                                        _selectedCategory == category
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground)
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    // MARK: - Apps
    
    private var _appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        _selectedCategory == "الكل"
                        ? "التطبيقات"
                        : _selectedCategory
                    )
                    .font(.title2.bold())
                    
                    Text("\(_filteredApps.count) تطبيق")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if _selectedCategory != "الكل" {
                    Button("الكل") {
                        withAnimation(.snappy) {
                            _selectedCategory = "الكل"
                        }
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, 16)
            
            if _filteredApps.isEmpty {
                _emptyAppsView
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(
                        Array(_filteredApps.enumerated()),
                        id: \.offset
                    ) { _, item in
                        _appCard(
                            source: item.source,
                            app: item.app
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func _appCard(
        source: ASRepository,
        app: ASRepository.App
    ) -> some View {
        Button {
            _selectedRoute = SourceAppRoute(
                source: source,
                app: app
            )
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: app.iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                            
                        default:
                            RoundedRectangle(
                                cornerRadius: 20,
                                style: .continuous
                            )
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 145,
                        maxHeight: 145
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 20,
                            style: .continuous
                        )
                    )
                    
                    if let version = app.currentVersion,
                       !version.isEmpty {
                        Text("v\(version)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name ?? "تطبيق")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if let subtitle = app.subtitle,
                       !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if let category = app.category,
                              !category.isEmpty {
                        Text(_categoryName(for: app))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let versions = app.versions,
               !versions.isEmpty {
                
                Menu(
                    "نسخ سابقة",
                    systemImage: "clock.arrow.circlepath"
                ) {
                    ForEach(
                        Array(versions.enumerated()),
                        id: \.offset
                    ) { _, version in
                        Button(version.version) {
                            if let url = version.downloadURL {
                                _ = DownloadManager.shared.startDownload(
                                    from: url,
                                    id: app.currentUniqueId
                                )
                            }
                        }
                    }
                }
                
                Menu(
                    "نسخ روابط التحميل",
                    systemImage: "doc.on.doc"
                ) {
                    ForEach(
                        Array(versions.enumerated()),
                        id: \.offset
                    ) { _, version in
                        Button(version.version) {
                            UIPasteboard.general.string =
                                version.downloadURL?.absoluteString
                        }
                    }
                }
            } else {
                Button(
                    "نسخ رابط التحميل",
                    systemImage: "doc.on.doc"
                ) {
                    UIPasteboard.general.string =
                        app.currentDownloadUrl?.absoluteString
                }
            }
        }
    }
    
    private var _emptyAppsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            
            Text("لا توجد تطبيقات")
                .font(.headline)
            
            Text(
                _searchText.isEmpty
                ? "لا توجد تطبيقات في هذه الفئة حالياً"
                : "لم يتم العثور على تطبيق يطابق بحثك"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Loading
    
    private var _loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            
            Text("جاري تحميل المتجر…")
                .font(.headline)
            
            Text("يتم جلب التطبيقات والمصادر")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sort Menu
    
    @ViewBuilder
    private var _sortMenu: some View {
        Section("ترتيب حسب") {
            ForEach(
                SortOption.allCases,
                id: \.rawValue
            ) { option in
                Button {
                    if _sortOption == option {
                        _sortAscending.toggle()
                    } else {
                        _sortOption = option
                        _sortAscending = true
                    }
                } label: {
                    HStack {
                        Text(option.displayName)
                        
                        Spacer()
                        
                        if _sortOption == option {
                            Image(
                                systemName:
                                    _sortAscending
                                    ? "checkmark"
                                    : "arrow.down"
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Loading
    
    private func _load() {
        _isLoading = true
        
        Task { @MainActor in
            let loadedSources = object.compactMap {
                viewModel.sources[$0]
            }
            
            withAnimation(.easeIn(duration: 0.2)) {
                _sources = loadedSources
                _isLoading = false
            }
        }
    }
    
    // MARK: - Categories
    
    private func _categoryName(
        for app: ASRepository.App
    ) -> String {
        guard let category = app.category,
              !category.isEmpty else {
            return "أخرى"
        }
        
        switch category.lowercased() {
        case "games":
            return "ألعاب"
        case "developer":
            return "تطوير"
        case "entertainment":
            return "ترفيه"
        case "education":
            return "تعليم"
        case "lifestyle":
            return "نمط حياة"
        case "photo-video":
            return "صور وفيديو"
        case "social":
            return "اجتماعي"
        case "utilities":
            return "أدوات"
        case "music":
            return "موسيقى"
        case "news":
            return "أخبار"
        case "health":
            return "صحة"
        case "finance":
            return "مالية"
        case "shopping":
            return "تسوق"
        case "travel":
            return "سفر"
        default:
            return category
        }
    }
    
    private func _categoryIcon(
        _ category: String
    ) -> String {
        switch category {
        case "الكل":
            return "square.grid.2x2"
        case "ألعاب":
            return "gamecontroller.fill"
        case "تطوير":
            return "chevron.left.forwardslash.chevron.right"
        case "ترفيه":
            return "play.tv.fill"
        case "تعليم":
            return "book.fill"
        case "نمط حياة":
            return "heart.fill"
        case "صور وفيديو":
            return "photo.fill"
        case "اجتماعي":
            return "person.2.fill"
        case "أدوات":
            return "wrench.and.screwdriver.fill"
        case "موسيقى":
            return "music.note"
        case "أخبار":
            return "newspaper.fill"
        case "صحة":
            return "cross.case.fill"
        case "مالية":
            return "banknote.fill"
        case "تسوق":
            return "bag.fill"
        case "سفر":
            return "airplane"
        default:
            return "square.grid.2x2"
        }
    }
    
    // MARK: - Route
    
    struct SourceAppRoute: Identifiable, Hashable {
        let source: ASRepository
        let app: ASRepository.App
        let id = UUID()
    }
    
    // MARK: - Fetch Request
    
    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \AltSource.name,
                ascending: true
            )
        ],
        animation: .snappy
    )
    private var _allSources: FetchedResults<AltSource>
}

// MARK: - Navigation Compatibility

extension View {
    @ViewBuilder
    func navigationDestinationIfAvailable<
        Item: Identifiable & Hashable,
        Destination: View
    >(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        if #available(iOS 17, *) {
            self.navigationDestination(
                item: item,
                destination: destination
            )
        } else {
            self
        }
    }
}
