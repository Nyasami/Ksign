import NimbleViews
import SwiftUI

struct JobsView: View {
	@StateObject private var _manager = JobsManager.shared
	@State private var _isDownloadsPresenting = false

	var body: some View {
		NBNavigationView(.localized("Jobs")) {
			NBListAdaptable {
				Section {
					Button {
						_isDownloadsPresenting = true
					} label: {
						Label(.localized("Open Downloads"), systemImage: "square.and.arrow.down.fill")
					}
				}

				if !_manager.activeJobs.isEmpty {
					NBSection(
						.localized("Active"),
						secondary: _manager.activeJobs.count.description
					) {
						ForEach(_manager.activeJobs) { job in
							JobRow(job: job)
						}
					}
				}

				NBSection(
					.localized("Recent"),
					secondary: _manager.recentJobs.count.description
				) {
					ForEach(_manager.recentJobs) { job in
						JobRow(job: job)
					}
				}
			}
			.overlay {
				if _manager.jobs.isEmpty {
					if #available(iOS 17, *) {
						ContentUnavailableView {
							Label(.localized("No Jobs"), systemImage: "clock.arrow.circlepath")
						} description: {
							Text(.localized("Downloads, imports, signing, extraction, and installation activity will appear here."))
						} actions: {
							Button(.localized("Open Downloads")) {
								_isDownloadsPresenting = true
							}
						}
					}
				}
			}
			.toolbar {
				if !_manager.recentJobs.isEmpty {
					NBToolbarButton(
						.localized("Clear"),
						style: .text,
						placement: .topBarTrailing
					) {
						_manager.clearFinished()
					}
				}
			}
			.sheet(isPresented: $_isDownloadsPresenting) {
				DownloaderView()
			}
		}
	}
}

private struct JobRow: View {
	@ObservedObject private var _manager = JobsManager.shared
	let job: JobRecord

	var body: some View {
		VStack(alignment: .leading, spacing: 7) {
			HStack(spacing: 10) {
				Image(systemName: job.kind.icon)
					.foregroundStyle(_color)
					.frame(width: 24)

				VStack(alignment: .leading, spacing: 2) {
					Text(job.title)
						.lineLimit(1)
					Text(job.detail.isEmpty ? job.kind.title : job.detail)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}

				Spacer()
				_actions
			}

			if !job.state.isFinished {
				ProgressView(value: job.progress)
					.progressViewStyle(.linear)
			}

			if let error = job.errorMessage {
				Text(error)
					.font(.caption)
					.foregroundStyle(.red)
					.textSelection(.enabled)
			}
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	private var _actions: some View {
		switch job.state {
		case .queued, .running:
			if _manager.canCancel(job.id) {
				Button(role: .destructive) {
					_manager.cancel(job.id)
				} label: {
					Image(systemName: "xmark.circle.fill")
				}
				.buttonStyle(.borderless)
			} else {
				ProgressView()
			}
		case .failed, .cancelled:
			if _manager.canRetry(job.id) || (job.kind == .download && job.sourceURL != nil) {
				Button {
					if !_manager.retry(job.id), let url = job.sourceURL, job.kind == .download {
						_ = DownloadManager.shared.startDownload(from: url)
					}
				} label: {
					Image(systemName: "arrow.clockwise")
				}
				.buttonStyle(.borderless)
			}
		case .completed:
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(.green)
		}
	}

	private var _color: Color {
		switch job.state {
		case .completed: return .green
		case .failed: return .red
		case .cancelled: return .secondary
		case .queued, .running: return .accentColor
		}
	}
}
