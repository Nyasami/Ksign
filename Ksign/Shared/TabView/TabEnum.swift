//
//  TabEnum.swift
//  Ksign
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case files
	case sources
	case library
	case settings
	case certificates
	case appstore
	case downloader
	
	var title: String {
		switch self {
		case .files:        return "الملفات"
		case .sources:      return "المصادر"
		case .library:      return "المكتبة"
		case .settings:     return "الإعدادات"
		case .certificates: return "الشهادات"
		case .appstore:     return "المتجر"
		case .downloader:   return "التنزيلات"
		}
	}
	
	var icon: String {
		switch self {
		case .files:        return "folder.fill"
		case .sources:      return "globe.americas.fill"
		case .library:      return "square.grid.2x2.fill"
		case .settings:     return "gearshape.fill"
		case .certificates: return "checkmark.seal.fill"
		case .appstore:     return "bag.fill"
		case .downloader:   return "arrow.down.circle.fill"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .files: FilesView()
		case .sources: SourcesView()
		case .library: LibraryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView("الشهادات") { CertificatesView() }
		case .appstore: AppstoreView()
		case .downloader: DownloaderView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.files,
			.library,
			.settings,
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates,
			.appstore,
			.downloader
		]
	}
}
