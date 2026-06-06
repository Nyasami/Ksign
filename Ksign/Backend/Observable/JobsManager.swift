import Combine
import Foundation

enum JobKind: String, Codable, CaseIterable {
	case download
	case importApp
	case signing
	case extraction
	case archive
	case installation
	case sourceRefresh
	case certificateImport

	var title: String {
		switch self {
		case .download: return .localized("Download")
		case .importApp: return .localized("Import")
		case .signing: return .localized("Signing")
		case .extraction: return .localized("Extraction")
		case .archive: return .localized("Archive")
		case .installation: return .localized("Installation")
		case .sourceRefresh: return .localized("Source Refresh")
		case .certificateImport: return .localized("Certificate Import")
		}
	}

	var icon: String {
		switch self {
		case .download: return "arrow.down.circle"
		case .importApp: return "square.and.arrow.down"
		case .signing: return "signature"
		case .extraction: return "archivebox"
		case .archive: return "doc.zipper"
		case .installation: return "arrow.down.app"
		case .sourceRefresh: return "arrow.triangle.2.circlepath"
		case .certificateImport: return "person.text.rectangle"
		}
	}
}

enum JobState: String, Codable {
	case queued
	case running
	case completed
	case failed
	case cancelled

	var isFinished: Bool {
		switch self {
		case .completed, .failed, .cancelled: return true
		case .queued, .running: return false
		}
	}
}

struct JobRecord: Identifiable, Codable, Equatable {
	let id: String
	let kind: JobKind
	var title: String
	var detail: String
	var progress: Double
	var state: JobState
	var errorMessage: String?
	var sourceURL: URL?
	let createdAt: Date
	var updatedAt: Date
	var finishedAt: Date?
}

final class JobsManager: ObservableObject {
	static let shared = JobsManager()

	@Published private(set) var jobs: [JobRecord] = []

	private let _storageKey = "ksign.jobs.history.v1"
	private let _historyLimit = 100
	private var _cancelActions: [String: () -> Void] = [:]
	private var _retryActions: [String: () -> Void] = [:]
	private var _persistWorkItem: DispatchWorkItem?

	private init() {
		if
			let data = UserDefaults.standard.data(forKey: _storageKey),
			let decoded = try? JSONDecoder().decode([JobRecord].self, from: data)
		{
			jobs = decoded.map { job in
				guard !job.state.isFinished else { return job }
				var interrupted = job
				interrupted.state = .failed
				interrupted.detail = .localized("Interrupted when Ksign closed")
				interrupted.errorMessage = .localized("The operation did not finish.")
				interrupted.finishedAt = Date()
				interrupted.updatedAt = Date()
				return interrupted
			}
			_persist()
		}
	}

	var activeJobs: [JobRecord] {
		jobs
			.filter { !$0.state.isFinished }
			.sorted { $0.createdAt > $1.createdAt }
	}

	var recentJobs: [JobRecord] {
		jobs
			.filter { $0.state.isFinished }
			.sorted { $0.updatedAt > $1.updatedAt }
	}

	@discardableResult
	func start(
		kind: JobKind,
		title: String,
		detail: String = "",
		sourceURL: URL? = nil,
		id: String = UUID().uuidString,
		cancel: (() -> Void)? = nil,
		retry: (() -> Void)? = nil
	) -> String {
		_mutate {
			let now = Date()
			let job = JobRecord(
				id: id,
				kind: kind,
				title: title,
				detail: detail,
				progress: 0,
				state: .running,
				errorMessage: nil,
				sourceURL: sourceURL,
				createdAt: now,
				updatedAt: now,
				finishedAt: nil
			)
			self.jobs.removeAll { $0.id == id }
			self.jobs.append(job)
			self._cancelActions[id] = cancel
			self._retryActions[id] = retry
			self._trimAndPersist()
		}
		return id
	}

	func update(
		_ id: String,
		progress: Double? = nil,
		detail: String? = nil,
		state: JobState? = nil
	) {
		_mutate {
			guard let index = self.jobs.firstIndex(where: { $0.id == id }) else { return }
			guard !self.jobs[index].state.isFinished else { return }
			if let progress {
				self.jobs[index].progress = max(0, min(1, progress))
			}
			if let detail {
				self.jobs[index].detail = detail
			}
			if let state {
				self.jobs[index].state = state
			}
			self.jobs[index].updatedAt = Date()
			self._schedulePersist()
		}
	}

	func complete(_ id: String, detail: String = "") {
		_finish(id, state: .completed, detail: detail, error: nil)
	}

	func fail(_ id: String, error: Error, detail: String = "") {
		_finish(id, state: .failed, detail: detail, error: error.localizedDescription)
	}

	func fail(_ id: String, message: String, detail: String = "") {
		_finish(id, state: .failed, detail: detail, error: message)
	}

	func cancel(_ id: String) {
		_mutate {
			self._cancelActions[id]?()
			self._finishOnMain(id, state: .cancelled, detail: .localized("Cancelled"), error: nil)
		}
	}

	@discardableResult
	func retry(_ id: String) -> Bool {
		var didRetry = false
		_mutate {
			guard let retry = self._retryActions[id] else { return }
			didRetry = true
			retry()
		}
		return didRetry
	}

	func canCancel(_ id: String) -> Bool {
		_cancelActions[id] != nil
	}

	func canRetry(_ id: String) -> Bool {
		_retryActions[id] != nil
	}

	func clearFinished() {
		_mutate {
			let finishedIDs = Set(self.jobs.filter { $0.state.isFinished }.map(\.id))
			self.jobs.removeAll { $0.state.isFinished }
			self._cancelActions = self._cancelActions.filter { !finishedIDs.contains($0.key) }
			self._retryActions = self._retryActions.filter { !finishedIDs.contains($0.key) }
			self._trimAndPersist()
		}
	}

	func clearAll() {
		_mutate {
			let cancelActions = Array(self._cancelActions.values)
			self.jobs.removeAll()
			self._cancelActions.removeAll()
			self._retryActions.removeAll()
			self._trimAndPersist()
			cancelActions.forEach { $0() }
		}
	}

	private func _finish(_ id: String, state: JobState, detail: String, error: String?) {
		_mutate {
			self._finishOnMain(id, state: state, detail: detail, error: error)
		}
	}

	private func _finishOnMain(_ id: String, state: JobState, detail: String, error: String?) {
		guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
		guard !jobs[index].state.isFinished else { return }
		jobs[index].state = state
		jobs[index].progress = state == .completed ? 1 : jobs[index].progress
		if !detail.isEmpty {
			jobs[index].detail = detail
		}
		jobs[index].errorMessage = error
		jobs[index].updatedAt = Date()
		jobs[index].finishedAt = Date()
		_cancelActions[id] = nil
		if state == .completed {
			_retryActions[id] = nil
		}
		_trimAndPersist()
	}

	private func _mutate(_ operation: @escaping () -> Void) {
		if Thread.isMainThread {
			operation()
		} else {
			DispatchQueue.main.sync(execute: operation)
		}
	}

	private func _trimAndPersist() {
		_persistWorkItem?.cancel()
		_persistWorkItem = nil
		let active = jobs.filter { !$0.state.isFinished }
		let finished = jobs
			.filter { $0.state.isFinished }
			.sorted { $0.updatedAt > $1.updatedAt }
			.prefix(_historyLimit)
		jobs = active + finished
		let retainedIDs = Set(jobs.map(\.id))
		_cancelActions = _cancelActions.filter { retainedIDs.contains($0.key) }
		_retryActions = _retryActions.filter { retainedIDs.contains($0.key) }
		_persist()
	}

	private func _schedulePersist() {
		_persistWorkItem?.cancel()
		let workItem = DispatchWorkItem { [weak self] in
			self?._persistWorkItem = nil
			self?._persist()
		}
		_persistWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
	}

	private func _persist() {
		guard let data = try? JSONEncoder().encode(jobs) else { return }
		UserDefaults.standard.set(data, forKey: _storageKey)
	}
}
