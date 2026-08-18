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
	case library
	case settings
	
	var title: String {
		switch self {
		case .files:    return "الملفات"
		case .library:  return "المكتبة"
		case .settings: return "الإعدادات"
		}
	}
	
	var icon: String {
		switch self {
		case .files:    return "folder.fill"
		case .library:  return "square.grid.2x2.fill"
		case .settings: return "gearshape.fill"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .files:    FilesView()
		case .library:  LibraryView()
		case .settings: SettingsView()
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
		return []
	}
}
