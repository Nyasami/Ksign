//
//  BulkInstallProgressView.swift
//  Ksign
//
//  Created by Nagata Asami on 27/1/26.
//

import SwiftUI
import NimbleViews
import IDeviceSwift
import OSLog

struct BulkInstallProgressView: View {
    var app: AppInfoPresentable
    @StateObject var viewModel = InstallerStatusViewModel()
    
    @AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
    @AppStorage("Feather.serverMethod") private var _serverMethod: Int = 0
    @StateObject var installer: ServerInstaller
    @State private var _isWebviewPresenting = false
    @State private var progressTask: Task<Void, Never>?
	@State private var _jobID: String?
	@State private var _hasStarted = false
    
    init(app: AppInfoPresentable) {
        self.app = app
        let method = UserDefaults.standard.integer(forKey: "Feather.installationMethod")
        let viewModel = InstallerStatusViewModel(isIdevice: method == 1)
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._installer = StateObject(wrappedValue: ServerInstaller(
            app: app,
            viewModel: viewModel,
            requiresServer: method == 0
        ))
    }
    
    var body: some View {
        VStack {
            InstallProgressView(app: app, viewModel: viewModel)
        }
        .sheet(isPresented: $_isWebviewPresenting) {
            SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
        }
        .onReceive(viewModel.$status) { newStatus in
			if let jobID = _jobID {
				JobsManager.shared.update(jobID, progress: viewModel.overallProgress, detail: viewModel.statusLabel)
				switch newStatus {
				case .completed:
					JobsManager.shared.complete(jobID, detail: viewModel.statusLabel)
				case .broken(let error):
					JobsManager.shared.fail(jobID, error: error, detail: viewModel.statusLabel)
				default:
					break
				}
			}
            if case .ready = newStatus {
                if _serverMethod == 0 {
                    if let url = URL(string: installer.iTunesLink) {
                        UIApplication.shared.open(url)
                    }
                } else if _serverMethod == 1 {
                    _isWebviewPresenting = true
                }
            }
            
            if case .installing = newStatus {
                if progressTask == nil, let bundleID = app.identifier {
                    progressTask = startInstallProgressPolling(
                        bundleID: bundleID,
                        viewModel: viewModel
                    )
                }
            }
            
            if case .sendingPayload = newStatus, _serverMethod == 1 {
                _isWebviewPresenting = false
            }
            
            switch newStatus {
            case .completed, .broken(_):
                progressTask?.cancel()
                progressTask = nil
                BackgroundAudioManager.shared.stop()
            default:
                break
            }
        }
        .onAppear(perform: _install)
		.onReceive(viewModel.$packageProgress) { progress in
			if let jobID = _jobID {
				JobsManager.shared.update(jobID, progress: progress * 0.45, detail: .localized("Packaging"))
			}
		}
		.onReceive(viewModel.$installProgress) { progress in
			if let jobID = _jobID {
				JobsManager.shared.update(jobID, progress: 0.55 + (progress * 0.45), detail: .localized("Installing"))
			}
		}
        .onAppear {
            BackgroundAudioManager.shared.start()
        }
        .onDisappear {
            progressTask?.cancel()
            progressTask = nil
            BackgroundAudioManager.shared.stop()
        }
    }
    
    private func _install() {
		guard !_hasStarted else { return }
		_hasStarted = true

		_jobID = JobsManager.shared.start(
			kind: .installation,
			title: app.name ?? .localized("Unknown App"),
			detail: .localized("Packaging")
		)
        if let error = installer.startupError {
            if let jobID = _jobID {
                JobsManager.shared.fail(jobID, error: error, detail: .localized("Installation failed"))
            }
            return
        }

        let appIdentifier = app.identifier
        Task.detached {
            do {
                let handler = await ArchiveHandler(app: app, viewModel: viewModel)
                try await handler.move()
                
                let packageUrl = try await handler.archive()
                
                if await _installationMethod == 0 {
                    await MainActor.run {
                        installer.packageUrl = packageUrl
                        viewModel.status = .ready
                    }
                    
                    if case .installing = await viewModel.status, let bundleID = appIdentifier {
                        let task = await startInstallProgressPolling(
                            bundleID: bundleID,
                            viewModel: viewModel
                        )

                        await MainActor.run {
                            progressTask = task
                        }
                    }
                } else if await _installationMethod == 1 {
                    let proxy = await InstallationProxy(viewModel: viewModel)
                    try await proxy.install(at: packageUrl, suspend: appIdentifier == Bundle.main.bundleIdentifier)
                }
                
            } catch {
                await MainActor.run {
					if let jobID = _jobID {
						JobsManager.shared.fail(jobID, error: error, detail: .localized("Installation failed"))
					}
                    HeartbeatManager.shared.start(true)
                }
            }
        }
    }
    
    private func startInstallProgressPolling(
        bundleID: String,
        viewModel: InstallerStatusViewModel
    ) -> Task<Void, Never> {

        Task.detached(priority: .background) {
            var hasStarted = false

            while !Task.isCancelled {
                let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0

                if rawProgress > 0 {
                    hasStarted = true
                }

                let progress = await hasStarted
                    ? _normalizeInstallProgress(rawProgress)
                    : 0.0

                Logger.misc.info("Install progress for \(bundleID): \(progress) - \(rawProgress) - \(viewModel.installProgress)")

                await MainActor.run {
                    viewModel.installProgress = progress
                }

                if hasStarted && rawProgress == 0 {
                    await MainActor.run {
                        viewModel.installProgress = 1.0
                        viewModel.status = .completed(.success(()))
                        print(viewModel.installProgress)
                    }
                    break
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
        min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
    }
}
