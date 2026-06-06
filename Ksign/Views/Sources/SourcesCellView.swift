//
//  SourcesCellView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesCellView: View {
	@ObservedObject private var _intelligence = SourceIntelligenceManager.shared
	var source: AltSource

	private var _insight: SourceInsight {
		_intelligence.insight(for: source)
	}
	
	// MARK: Body
	var body: some View {
		FRIconCellView(
			title: source.name ?? .localized("Unknown"),
			subtitle: source.sourceURL?.absoluteString ?? "",
			iconUrl: source.iconURL
		)
		.overlay(alignment: .bottomTrailing) {
			HStack(spacing: 4) {
				if _insight.isFavorite {
					Image(systemName: "star.fill")
						.foregroundStyle(.yellow)
				}
				Image(systemName: _insight.health.icon)
					.foregroundStyle(_healthColor)
				if _insight.updateCount > 0 {
					Text(_insight.updateCount.description)
						.foregroundStyle(.orange)
				}
			}
			.font(.caption)
		}
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(
			_insight.isFavorite ? .localized("Remove Favorite") : .localized("Favorite"),
			systemImage: _insight.isFavorite ? "star.slash" : "star"
		) {
			_intelligence.toggleFavorite(source)
		}
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}

	private var _healthColor: Color {
		switch _insight.health {
		case .healthy: return .green
		case .degraded: return .orange
		case .offline: return .red
		case .unchecked: return .secondary
		}
	}
}
