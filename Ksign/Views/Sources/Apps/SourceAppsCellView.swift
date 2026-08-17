//
//  SourceAppsView.swift
//  Ksign
//
//  Redesigned Store UI
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit
import NukeUI

struct SourceAppsView: View {

    // MARK: - Store Categories

    enum StoreCategory: String, CaseIterable, Identifiable {
        case all
        case apps
        case games
        case tools
        case entertainment
        case new

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "الكل"
            case .apps:
                return "تطبيقات"
            case .games:
                return "ألعاب"
            case .tools:
                return "أدوات"
            case .entertainment:
                return "ترفيه"
            case .new:
                return "جديد"
            }
        }

        var icon: String {
            switch self {
            case .all:
                return "square.grid.2x2"
            case .apps:
                return "apps.iphone"
            case .games:
                return "gamecontroller"
            case .tools:
                return "wrench.and.screwdriver"
            case .entertainment:
                return "play.tv"
            case .new:
                return "sparkles"
            }
        }
    }

    // MARK: - Properties

    @StateObject private var _viewModel = SourcesViewModel.shared

    @State private var _selectedRoute: SourceAppRoute?
    @State private var _searchText = ""
    @State private var _selectedCategory: StoreCategory = .all
    @State private var _isRefreshing = false

    @State var isLoading = true
    @State var hasLoadedOnce = false

    var fromAppStore: Bool = false

    var object: [AltSource]
    @ObservedObject var viewModel: SourcesViewModel

    @State private var _sources: [ASRepository]?

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

    // MARK: - Navigation Title

    private var _navigationTitle: String {
        if fromAppStore {
            return "المتجر"
        }

        if object.count == 1 {
            return object[0].name ?? "غير معروف"
        }

        return "\(object.count) مصادر"
    }

    // MARK: - All Apps

    private var allApps: [(source: ASRepository, app: ASRepository.App)] {
        guard let sources = _sources else {
            return []
        }

        return sources.flatMap { source in
            source.apps.map {
                (
                    source: source,
                    app: $0
                )
            }
        }
    }

    // MARK: - Filtered Apps

    private var filteredApps: [(source: ASRepository, app: ASRepository.App)] {
        var result = allApps

        // Search
        if !_searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = _searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            result = result.filter { item in
                let name = item.app.currentName
                let description = item.app.currentDescription ?? ""
                let localizedDescription = item.app.localizedDescription ?? ""
                let version = item.app.currentVersion ?? ""

                return name.localizedCaseInsensitiveContains(query)
                    || description.localizedCaseInsensitiveContains(query)
                    || localizedDescription.localizedCaseInsensitiveContains(query)
                    || version.localizedCaseInsensitiveContains(query)
            }
        }

        // Category
        switch _selectedCategory {
        case .all:
            break

        case .new:
            result = result.sorted {
                let firstDate = $0.app.currentDate?.date ?? .distantPast
                let secondDate = $1.app.currentDate?.date ?? .distantPast
                return firstDate > secondDate
            }

        case .apps:
            result = result.filter {
                !containsGameKeyword(
                    name: $0.app.currentName,
                    description: $0.app.currentDescription
                )
            }

        case .games:
            result = result.filter {
                containsGameKeyword(
                    name: $0.app.currentName,
                    description: $0.app.currentDescription
                )
            }

        case .tools:
            result = result.filter {
                containsKeyword(
                    name: $0.app.currentName,
                    description: $0.app.currentDescription,
                    keywords: [
                        "tool",
                        "tools",
                        "utility",
                        "utilities",
                        "editor",
                        "manager",
                        "file",
                        "download",
                        "browser",
                        "أداة",
                        "أدوات",
                        "مدير",
                        "ملفات",
                        "تحميل",
                        "متصفح"
                    ]
                )
            }

        case .entertainment:
            result = result.filter {
                containsKeyword(
                    name: $0.app.currentName,
                    description: $0.app.currentDescription,
                    keywords: [
                        "youtube",
                        "netflix",
                        "spotify",
                        "music",
                        "video",
                        "movie",
                        "tv",
                        "stream",
                        "تلفزيون",
                        "فيديو",
                        "موسيقى",
                        "أفلام",
                        "ترفيه"
                    ]
                )
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 22
            ) {

                // Banner
                storeBanner

                // Categories
                categoriesSection

                // Search result / Featured
                if _searchText.isEmpty {
                    featuredSection
                }

                // Apps
                appsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .environment(\.layoutDirection, .rightToLeft)
        .navigationTitle(_navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $_searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "ابحث عن تطبيق أو لعبة"
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

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    refreshStore()
                } label: {
                    Image(
                        systemName: _isRefreshing
                        ? "arrow.trianglehead.2.counterclockwise.rotate.90"
                        : "arrow.clockwise"
                    )
                }
                .disabled(_isRefreshing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("نسخ روابط المصادر", systemImage: "doc.on.doc") {
                        copySourceLinks()
                    }

                    Divider()

                    Button("إعادة تحميل المتجر", systemImage: "arrow.clockwise") {
                        refreshStore()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isLoading {
                loadingView
            }
        }
        .onAppear {
            if !hasLoadedOnce, viewModel.isFinished {
                _load()
                hasLoadedOnce = true
            }
        }
        .onChange(of: viewModel.isFinished) { _ in
            _load()
        }
        .navigationDestinationIfAvailable(
            item: $_selectedRoute
        ) { route in
            SourceAppsDetailView(
                source: route.source,
                app: route.app
            )
        }
    }

    // MARK: - Banner

    private var storeBanner: some View {
        ZStack(alignment: .bottomTrailing) {

            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.95),
                            Color.accentColor.opacity(0.55),
                            Color.black.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 190, height: 190)
                .offset(x: 55, y: -55)

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .offset(x: -90, y: 60)

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2.weight(.bold))

                    Text("ONEs Store")
                        .font(.headline.weight(.bold))

                    Spacer()
                }

                Text("اكتشف تطبيقاتك المفضلة")
                    .font(.title2.weight(.bold))

                Text("تصفح التطبيقات والألعاب والأدوات من مكان واحد")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")

                    Text("\(allApps.count) تطبيق")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.14))
                .clipShape(Capsule())
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(
            color: .black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 6
        )
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("الفئات")
                .font(.title3.weight(.bold))

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 10) {
                    ForEach(StoreCategory.allCases) { category in
                        categoryButton(category)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private func categoryButton(
        _ category: StoreCategory
    ) -> some View {
        let selected = _selectedCategory == category

        return Button {
            withAnimation(.snappy) {
                _selectedCategory = category
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: category.icon)

                Text(category.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(
                selected
                ? Color.white
                : Color.primary
            )
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(
                        selected
                        ? Color.accentColor
                        : Color(uiColor: .secondarySystemGroupedBackground)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Featured

    @ViewBuilder
    private var featuredSection: some View {
        if !allApps.isEmpty {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                HStack {
                    Text("مميزة")
                        .font(.title3.weight(.bold))

                    Spacer()

                    Text("مختارات المتجر")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(spacing: 14) {
                        ForEach(
                            Array(
                                allApps.prefix(6).enumerated()
                            ),
                            id: \.offset
                        ) { _, item in

                            FeaturedAppCard(
                                source: item.source,
                                app: item.app
                            ) {
                                _selectedRoute =
                                    SourceAppRoute(
                                        source: item.source,
                                        app: item.app
                                    )
                            }
                        }
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    // MARK: - Apps Section

    private var appsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Text(
                    _searchText.isEmpty
                    ? "التطبيقات"
                    : "نتائج البحث"
                )
                .font(.title3.weight(.bold))

                Spacer()

                Text("\(filteredApps.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if filteredApps.isEmpty {
                emptyAppsView
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .flexible(),
                            spacing: 12
                        ),
                        GridItem(
                            .flexible(),
                            spacing: 12
                        )
                    ],
                    spacing: 14
                ) {
                    ForEach(
                        Array(
                            filteredApps.enumerated()
                        ),
                        id: \.offset
                    ) { _, item in

                        StoreAppCard(
                            source: item.source,
                            app: item.app
                        ) {
                            _selectedRoute =
                                SourceAppRoute(
                                    source: item.source,
                                    app: item.app
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyAppsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text("لا توجد تطبيقات")
                .font(.headline)

            Text(
                _searchText.isEmpty
                ? "لم يتم العثور على تطبيقات في هذه الفئة."
                : "جرب البحث باسم مختلف."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 180
        )
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                Text("جاري تحميل المتجر...")
                    .font(.headline)

                Text("يتم جلب التطبيقات من المصادر")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Loading

    private func _load() {
        isLoading = true

        Task {
            let loadedSources = object.compactMap {
                viewModel.sources[$0]
            }

            await MainActor.run {
                _sources = loadedSources

                withAnimation(.easeIn(duration: 0.2)) {
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Refresh

    private func refreshStore() {
        guard !_isRefreshing else {
            return
        }

        _isRefreshing = true

        Task {
            await viewModel.fetchSources(
                _allSources,
                refresh: true
            )

            await MainActor.run {
                _isRefreshing = false
            }
        }
    }

    // MARK: - Copy Sources

    private func copySourceLinks() {
        let links = object.compactMap {
            $0.sourceURL?.absoluteString
        }

        UIPasteboard.general.string =
            links.joined(separator: "\n")

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
    }

    // MARK: - Helpers

    private func containsGameKeyword(
        name: String,
        description: String?
    ) -> Bool {
        containsKeyword(
            name: name,
            description: description,
            keywords: [
                "game",
                "games",
                "gaming",
                "arcade",
                "puzzle",
                "racing",
                "pubg",
                "minecraft",
                "fortnite",
                "لعبة",
                "ألعاب",
                "العاب",
                "لعب"
            ]
        )
    }

    private func containsKeyword(
        name: String,
        description: String?,
        keywords: [String]
    ) -> Bool {
        let text = (
            name + " " + (description ?? "")
        ).lowercased()

        return keywords.contains {
            text.contains($0.lowercased())
        }
    }

    // MARK: - Route

    struct SourceAppRoute:
        Identifiable,
        Hashable {

        let source: ASRepository
        let app: ASRepository.App
        let id: String

        init(
            source: ASRepository,
            app: ASRepository.App
        ) {
            self.source = source
            self.app = app
            self.id =
                "\(app.currentUniqueId)-\(UUID().uuidString)"
        }

        static func == (
            lhs: SourceAppRoute,
            rhs: SourceAppRoute
        ) -> Bool {
            lhs.id == rhs.id
        }

        func hash(
            into hasher: inout Hasher
        ) {
            hasher.combine(id)
        }
    }
}

// MARK: - Featured Card

private struct FeaturedAppCard: View {

    let source: ASRepository
    let app: ASRepository.App
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {

                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.8),
                                Color.black.opacity(0.9)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )

                if let iconURL = app.iconURL {
                    LazyImage(url: iconURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: 125,
                                    height: 125
                                )
                                .blur(radius: 16)
                                .opacity(0.25)
                        }
                    }
                }

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Spacer()

                    appIcon

                    Text(app.currentName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(
                        app.currentDescription
                        ?? "تطبيق رائع"
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                }
                .padding(16)
            }
            .frame(
                width: 235,
                height: 210
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 24)
            )
        }
        .buttonStyle(.plain)
    }

    private var appIcon: some View {
        Group {
            if let iconURL = app.iconURL {
                LazyImage(url: iconURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(
            RoundedRectangle(cornerRadius: 14)
        )
        .shadow(
            color: .black.opacity(0.25),
            radius: 8
        )
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white.opacity(0.15))
            .overlay {
                Image(systemName: "app.fill")
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Store App Card

private struct StoreAppCard: View {

    let source: ASRepository
    let app: ASRepository.App
    let action: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Button(action: action) {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    appIcon

                    Text(app.currentName)
                        .font(
                            .system(
                                .headline,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(
                        app.currentDescription
                        ?? "تطبيق"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                    if let version = app.currentVersion,
                       !version.isEmpty {

                        Text("الإصدار \(version)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .buttonStyle(.plain)

            DownloadButtonView(app: app)
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
        }
        .padding(12)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        }
        .shadow(
            color: .black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 3
        )
    }

    private var appIcon: some View {
        Group {
            if let iconURL = app.iconURL {
                LazyImage(url: iconURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(
            width: 72,
            height: 72
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 17)
        )
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 17)
            .fill(Color.accentColor.opacity(0.12))
            .overlay {
                Image(systemName: "app.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)
            }
    }
}

// MARK: - iOS Compatibility

extension View {

    @ViewBuilder
    func navigationDestinationIfAvailable<
        Item: Identifiable & Hashable,
        Destination: View
    >(
        item: Binding<Item?>,
        @ViewBuilder destination:
            @escaping (Item) -> Destination
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
