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

// MARK: - Extension: View (Enum)
extension SourceAppsView {
    enum SortOption: String, CaseIterable {
        case `default` = "default"
        case name
        case date
        
        var displayName: String {
            switch self {
            case .default:  return "الافتراضي"
            case .name:     return "الاسم"
            case .date:     return "التاريخ"
            }
        }
    }
}

// MARK: - View
struct SourceAppsView: View {
    @AppStorage("Feather.sortOptionRawValue") private var _sortOptionRawValue: String = SortOption.default.rawValue
    @AppStorage("Feather.sortAscending") private var _sortAscending: Bool = true
    
    @State private var _sortOption: SortOption = .default
    @State private var _selectedRoute: SourceAppRoute?
    
    @State var isLoading = true
    @State var hasLoadedOnce = false
    @State private var _searchText = ""
    var fromAppStore: Bool = false
    
    private var _navigationTitle: String {
        if fromAppStore {
            return "المتجر"
        } else if object.count == 1 {
            return object[0].name ?? "غير معروف"
        } else {
            return "\(object.count) مصادر"
        }
    }
    
    var object: [AltSource]
    @ObservedObject var viewModel: SourcesViewModel
    @State private var _sources: [ASRepository]?
    
    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _allSources: FetchedResults<AltSource>
    
    // MARK: Body
    var body: some View {
        ZStack {
            if
                let _sources,
                !_sources.isEmpty
            {
                SourceAppsTableRepresentableView(
                    sources: _sources,
                    searchText: $_searchText,
                    sortOption: $_sortOption,
                    sortAscending: $_sortAscending,
                    onSelect: {self._selectedRoute = $0}
                )
                .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    
                    VStack(spacing: 6) {
                        Text("جاري التحميل...")
                            .font(.headline)
                        
                        Text("تعذر التحميل؟ تأكد من إضافة مصدر أولاً")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .navigationTitle(_navigationTitle)
        .searchable(text: $_searchText, placement: .platform(), prompt: "بحث عن تطبيق")
        .toolbarTitleMenu {
            if
                let _sources,
                _sources.count == 1
            {
                if let url = _sources[0].website {
                    Button("زيارة الموقع", systemImage: "globe") {
                        UIApplication.open(url)
                    }
                }
                
                if let url = _sources[0].patreonURL {
                    Button("دعم عبر باتريون", systemImage: "dollarsign.circle") {
                        UIApplication.open(url)
                    }
                }
            }
            
            Divider()
            
            Button("نسخ الرابط", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = object.map {
                    $0.sourceURL!.absoluteString
                }.joined(separator: "\n")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
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
            
            NBToolbarButton(
                systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90",
                style: .icon,
                placement: .topBarTrailing
            ) {
                Task {
                    await viewModel.fetchSources(_allSources, refresh: true)
                }
            }
            
            NBToolbarMenu(
                systemImage: "line.3.horizontal.decrease.circle",
                style: .icon,
                placement: .topBarTrailing
            ) {
                _sortActions()
            }
        }
        .onAppear {
            if !hasLoadedOnce, viewModel.isFinished {
                _load()
                hasLoadedOnce = true
            }
            _sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .default
        }
        .onChange(of: viewModel.isFinished) { _ in
            _load()
        }
        .onChange(of: _sortOption) { newValue in
            _sortOptionRawValue = newValue.rawValue
        }
        .navigationDestinationIfAvailable(item: $_selectedRoute) { route in
            SourceAppsDetailView(source: route.source, app: route.app)
        }
        
    }
    
    private func _load() {
        isLoading = true
        
        Task {
            let loadedSources = object.compactMap { viewModel.sources[$0] }
            _sources = loadedSources
            withAnimation(.easeIn(duration: 0.2)) {
                isLoading = false
            }
        }
    }
    
    struct SourceAppRoute: Identifiable, Hashable {
        let source: ASRepository
        let app: ASRepository.App
        let id: String = UUID().uuidString
    }
}

// MARK: - Extension: View (Sort)
extension SourceAppsView {
    @ViewBuilder
    private func _sortActions() -> some View {
        Section("ترتيب حسب") {
            ForEach(SortOption.allCases, id: \.displayName) { opt in
                _sortButton(for: opt)
            }
        }
    }
    
    private func _sortButton(for option: SortOption) -> some View {
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
                    Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
                }
            }
        }
    }
}

import SwiftUI

extension View {
    @ViewBuilder
    func navigationDestinationIfAvailable<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        if #available(iOS 17, *) {
            self.navigationDestination(item: item, destination: destination)
        } else {
            self
        }
    }
}
