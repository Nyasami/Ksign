import AltSourceKit
import NimbleViews
import SwiftUI

struct SourceIntelligenceView: View {
	@StateObject private var _intelligence = SourceIntelligenceManager.shared
	@StateObject private var _viewModel = SourcesViewModel.shared

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	private var _favorites: [AltSource] {
		_sources.filter { _intelligence.insight(for: $0).isFavorite }
	}

	private var _attentionNeeded: [AltSource] {
		_sources.filter {
			let insight = _intelligence.insight(for: $0)
			return insight.health == .degraded
				|| insight.health == .offline
				|| insight.trust == .untrusted
				|| insight.updateCount > 0
				|| insight.contentChanged
		}
	}

	var body: some View {
		NBList(.localized("Source Intelligence")) {
			NBSection(.localized("Summary")) {
				LabeledContent(.localized("Available Updates"), value: _intelligence.updateBundleIDs.count.description)
				LabeledContent(.localized("Favorites"), value: _favorites.count.description)
				LabeledContent(.localized("Needs Attention"), value: _attentionNeeded.count.description)
			}

			if !_favorites.isEmpty {
				NBSection(.localized("Favorites")) {
					ForEach(_favorites) { source in
						_sourceLink(source)
					}
				}
			}

			if !_attentionNeeded.isEmpty {
				NBSection(.localized("Needs Attention")) {
					ForEach(_attentionNeeded) { source in
						_sourceLink(source)
					}
				}
			}

			NBSection(.localized("All Sources")) {
				ForEach(_sources) { source in
					_sourceLink(source)
				}
			}
		}
		.refreshable {
			await _viewModel.fetchSources(_sources, refresh: true)
		}
	}

	private func _sourceLink(_ source: AltSource) -> some View {
		NavigationLink {
			SourceAppsView(object: [source], viewModel: _viewModel)
		} label: {
			SourceIntelligenceRow(source: source)
		}
		.buttonStyle(.plain)
	}
}

struct SourceIntelligenceRow: View {
	@ObservedObject private var _intelligence = SourceIntelligenceManager.shared
	let source: AltSource

	private var _insight: SourceInsight {
		_intelligence.insight(for: source)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Label(source.name ?? .localized("Unknown"), systemImage: _insight.health.icon)
					.foregroundStyle(_healthColor)
				Spacer()
				if _insight.isFavorite {
					Image(systemName: "star.fill")
						.foregroundStyle(.yellow)
				}
			}

			HStack(spacing: 12) {
				Label(_insight.trust.title, systemImage: _insight.trust.icon)
				Label("\(_insight.appCount)", systemImage: "square.grid.2x2")
				if _insight.updateCount > 0 {
					Label("\(_insight.updateCount)", systemImage: "arrow.down.app.fill")
						.foregroundStyle(.orange)
				}
				if _insight.contentChanged {
					Label(.localized("Changed"), systemImage: "sparkles")
						.foregroundStyle(.blue)
				}
				if let lastChecked = _insight.lastChecked {
					Label(
						lastChecked.formatted(date: .abbreviated, time: .shortened),
						systemImage: "clock"
					)
				}
			}
			.font(.caption)
			.foregroundStyle(.secondary)

			if let error = _insight.lastError {
				Text(error)
					.font(.caption)
					.foregroundStyle(.red)
					.lineLimit(2)
			}
		}
		.contextMenu {
			Button {
				_intelligence.toggleFavorite(source)
			} label: {
				Label(
					_insight.isFavorite ? .localized("Remove Favorite") : .localized("Favorite"),
					systemImage: _insight.isFavorite ? "star.slash" : "star"
				)
			}

			Menu(.localized("Trust"), systemImage: "checkmark.shield") {
				Button(.localized("Trusted")) {
					_intelligence.setTrust(.trusted, for: source)
				}
				Button(.localized("Untrusted")) {
					_intelligence.setTrust(.untrusted, for: source)
				}
				Button(.localized("Unreviewed")) {
					_intelligence.setTrust(.unknown, for: source)
				}
			}
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
