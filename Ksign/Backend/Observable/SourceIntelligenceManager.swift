import AltSourceKit
import Combine
import CoreData
import CryptoKit
import Foundation

enum SourceHealth: String, Codable {
	case unchecked
	case healthy
	case degraded
	case offline

	var title: String {
		switch self {
		case .unchecked: return .localized("Unchecked")
		case .healthy: return .localized("Healthy")
		case .degraded: return .localized("Degraded")
		case .offline: return .localized("Offline")
		}
	}

	var icon: String {
		switch self {
		case .unchecked: return "questionmark.circle"
		case .healthy: return "checkmark.circle.fill"
		case .degraded: return "exclamationmark.triangle.fill"
		case .offline: return "xmark.octagon.fill"
		}
	}
}

enum SourceTrust: String, Codable {
	case unknown
	case trusted
	case untrusted

	var title: String {
		switch self {
		case .unknown: return .localized("Unreviewed")
		case .trusted: return .localized("Trusted")
		case .untrusted: return .localized("Untrusted")
		}
	}

	var icon: String {
		switch self {
		case .unknown: return "questionmark.shield"
		case .trusted: return "checkmark.shield.fill"
		case .untrusted: return "xmark.shield.fill"
		}
	}
}

struct SourceInsight: Codable, Equatable {
	var isFavorite = false
	var trust: SourceTrust = .unknown
	var health: SourceHealth = .unchecked
	var lastChecked: Date?
	var lastSuccessfulFetch: Date?
	var lastError: String?
	var consecutiveFailures = 0
	var appCount = 0
	var updateCount = 0
	var fingerprint: String?
	var contentChanged = false
}

final class SourceIntelligenceManager: ObservableObject {
	static let shared = SourceIntelligenceManager()

	@Published private(set) var insights: [String: SourceInsight] = [:]
	@Published private(set) var updateBundleIDs: Set<String> = []

	private let _storageKey = "ksign.source.intelligence.v1"
	private let _updatesStorageKey = "ksign.source.intelligence.updates.v1"
	private var _updatesBySource: [String: Set<String>] = [:]
	private var _localVersions: [String: [String]] = [:]
	private var _hasLocalVersionSnapshot = false

	private init() {
		if
			let data = UserDefaults.standard.data(forKey: _storageKey),
			let decoded = try? JSONDecoder().decode([String: SourceInsight].self, from: data)
		{
			insights = decoded
		}
		if
			let data = UserDefaults.standard.data(forKey: _updatesStorageKey),
			let decoded = try? JSONDecoder().decode([String: Set<String>].self, from: data)
		{
			_updatesBySource = decoded
			_refreshUpdateBundleIDs()
		}
	}

	func key(for source: AltSource) -> String {
		source.identifier
	}

	func insight(for source: AltSource) -> SourceInsight {
		if let stored = insights[key(for: source)] {
			return stored
		}
		var initial = SourceInsight()
		if source.isBuiltIn {
			initial.trust = .trusted
		}
		return initial
	}

	func toggleFavorite(_ source: AltSource) {
		_update(source) { $0.isFavorite.toggle() }
	}

	func setTrust(_ trust: SourceTrust, for source: AltSource) {
		_update(source) { $0.trust = trust }
	}

	func remove(_ source: AltSource) {
		let sourceKey = key(for: source)
		insights[sourceKey] = nil
		_updatesBySource[sourceKey] = nil
		_refreshUpdateBundleIDs()
		_persist()
	}

	func clearAll() {
		insights.removeAll()
		_updatesBySource.removeAll()
		_localVersions.removeAll()
		_hasLocalVersionSnapshot = false
		updateBundleIDs.removeAll()
		UserDefaults.standard.removeObject(forKey: _storageKey)
		UserDefaults.standard.removeObject(forKey: _updatesStorageKey)
	}

	func prepareForRefresh() {
		_localVersions = _readLocalVersions()
		_hasLocalVersionSnapshot = true
	}

	func invalidateLocalVersionSnapshot() {
		_localVersions.removeAll()
		_hasLocalVersionSnapshot = false
		objectWillChange.send()
	}

	func recordSuccess(source: AltSource, repository: ASRepository) {
		let sourceKey = key(for: source)
		let fingerprint = _fingerprint(repository)
		let updateIDs = _updateIDs(in: repository)

		_updatesBySource[sourceKey] = updateIDs
		_refreshUpdateBundleIDs()

		_update(source) { insight in
			insight.contentChanged = insight.fingerprint != nil && insight.fingerprint != fingerprint
			insight.fingerprint = fingerprint
			insight.health = .healthy
			insight.lastChecked = Date()
			insight.lastSuccessfulFetch = Date()
			insight.lastError = nil
			insight.consecutiveFailures = 0
			insight.appCount = repository.apps.count
			insight.updateCount = updateIDs.count
		}
	}

	func recordFailure(source: AltSource, error: Error) {
		recordFailure(source: source, message: error.localizedDescription)
	}

	func recordFailure(source: AltSource, message: String) {
		_update(source) { insight in
			insight.lastChecked = Date()
			insight.lastError = message
			insight.consecutiveFailures += 1
			insight.health = insight.consecutiveFailures >= 3 ? .offline : .degraded
		}
	}

	func isUpdateAvailable(for app: ASRepository.App) -> Bool {
		guard
			let id = app.id,
			let currentVersion = app.currentVersion,
			updateBundleIDs.contains(id)
		else {
			return false
		}

		if !_hasLocalVersionSnapshot {
			prepareForRefresh()
		}
		guard let installed = _localVersions[id] else { return false }
		return Self.isNewerVersion(currentVersion, than: installed)
	}

	static func isNewerVersion(_ candidate: String, than installedVersions: [String]) -> Bool {
		guard !installedVersions.isEmpty else { return false }
		return installedVersions.allSatisfy {
			candidate.compare($0, options: [.numeric, .caseInsensitive]) == .orderedDescending
		}
	}

	private func _update(_ source: AltSource, operation: (inout SourceInsight) -> Void) {
		let sourceKey = key(for: source)
		var insight = insight(for: source)
		operation(&insight)
		insights[sourceKey] = insight
		_persist()
	}

	private func _refreshUpdateBundleIDs() {
		updateBundleIDs = _updatesBySource.values.reduce(into: Set<String>()) {
			$0.formUnion($1)
		}
	}

	private func _updateIDs(in repository: ASRepository) -> Set<String> {
		let localVersions = _hasLocalVersionSnapshot ? _localVersions : _readLocalVersions()

		return Set(repository.apps.compactMap { app in
			guard
				let id = app.id,
				let currentVersion = app.currentVersion,
				let installed = localVersions[id],
				Self.isNewerVersion(currentVersion, than: installed)
			else {
				return nil
			}
			return id
		})
	}

	private func _readLocalVersions() -> [String: [String]] {
		let importedRequest: NSFetchRequest<Imported> = Imported.fetchRequest()
		let signedRequest: NSFetchRequest<Signed> = Signed.fetchRequest()
		var versions: [String: [String]] = [:]

		Storage.shared.context.performAndWait {
			let imported: [AppInfoPresentable] = ((try? Storage.shared.context.fetch(importedRequest)) ?? [])
				.map { $0 as AppInfoPresentable }
			let signed: [AppInfoPresentable] = ((try? Storage.shared.context.fetch(signedRequest)) ?? [])
				.map { $0 as AppInfoPresentable }
			let localApps = imported + signed

			versions = Dictionary(grouping: localApps.compactMap { app -> (String, String)? in
				guard let id = app.identifier, let version = app.version else { return nil }
				return (id, version)
			}, by: { $0.0 }).mapValues { $0.map { $0.1 } }
		}

		return versions
	}

	private func _fingerprint(_ repository: ASRepository) -> String {
		let contents = repository.apps
			.map {
				[
					$0.id ?? "",
					$0.currentVersion ?? "",
					$0.currentDownloadUrl?.absoluteString ?? ""
				].joined(separator: "|")
			}
			.sorted()
			.joined(separator: "\n")
		return SHA256.hash(data: Data(contents.utf8))
			.map { String(format: "%02x", $0) }
			.joined()
	}

	private func _persist() {
		let encoder = JSONEncoder()
		if let data = try? encoder.encode(insights) {
			UserDefaults.standard.set(data, forKey: _storageKey)
		}
		if let data = try? encoder.encode(_updatesBySource) {
			UserDefaults.standard.set(data, forKey: _updatesStorageKey)
		}
	}
}
