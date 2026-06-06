//
//  IPADownloadManager.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

class IPADownloadManager: NSObject, ObservableObject {
	static let shared = IPADownloadManager()

    @Published var downloadItems: [DownloadItem] = []
    
    var activeItems: [DownloadItem] {
        downloadItems.filter { !$0.isFinished }
    }
    
    var finishedItems: [DownloadItem] {
        downloadItems.filter { $0.isFinished }
    }
    
    private var urlSession: URLSession!
    private var activeDownloads: [Int: String] = [:] // taskIdentifier -> downloadItem.id
	private let activeDownloadsLock = NSLock()
    
    override init() {
        super.init()
        setupURLSession()
        loadDownloadedIPAs()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300 // 5 minutes
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func isIPAFile(_ url: URL) -> Bool {
        return url.pathExtension.lowercased() == "ipa"
    }

    func loadDownloadedIPAs() {
        let fileManager = FileManager.default
        
        let downloadDirectory = URL.documentsDirectory.appendingPathComponent("Downloads")
        
        
        let activeDownloads = downloadItems.filter { !$0.isFinished }
        downloadItems.removeAll()
        
        downloadItems.append(contentsOf: activeDownloads)
        
        do {
            try fileManager.createDirectoryIfNeeded(at: downloadDirectory)
            
            let fileURLs = try fileManager.contentsOfDirectory(at: downloadDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [])
            
            for fileURL in fileURLs {
                if isIPAFile(fileURL) {
                    if activeDownloads.contains(where: { $0.localPath == fileURL }) {
                        continue
                    }
                    
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    let item = DownloadItem(
                        title: fileURL.lastPathComponent,
                        url: fileURL,
                        localPath: fileURL,
                        isFinished: true,
                        progress: 1.0,
                        totalBytes: fileSize,
                        bytesDownloaded: fileSize
                    )
                    downloadItems.append(item)
                }
            }
            
        } catch {
            print("Failed to load downloaded IPAs: \(error)")
        }
    }
    
    func startDownload(url: URL, filename: String) {
        let fileManager = FileManager.default
        let downloadDirectory = URL.documentsDirectory.appendingPathComponent("Downloads")
        try? fileManager.createDirectoryIfNeeded(at: downloadDirectory)
		let safeFilename = URL(fileURLWithPath: filename).lastPathComponent.isEmpty
			? "app.ipa"
			: URL(fileURLWithPath: filename).lastPathComponent
        
        let destinationURL = downloadDirectory.appendingPathComponent(safeFilename)
        let item = DownloadItem(
            title: safeFilename,
            url: url,
            localPath: destinationURL,
            isFinished: false,
            progress: 0,
            totalBytes: 0,
            bytesDownloaded: 0
        )
        
        _onMain {
            self.downloadItems.insert(item, at: 0)
        }
        
        let task = urlSession.downloadTask(with: url)
        
        _setActiveDownload(item.id.uuidString, for: task.taskIdentifier)
		let jobID = "browser-download.\(item.id.uuidString)"
		JobsManager.shared.start(
			kind: .download,
			title: safeFilename,
			detail: .localized("Downloading"),
			sourceURL: url,
			id: jobID,
			cancel: { [weak self] in
				self?.cancelDownload(item, updateJob: false)
			},
			retry: { [weak self] in
				self?.startDownload(url: url, filename: safeFilename)
			}
		)
        
        task.resume()
    }
    
    
    func cancelDownload(_ item: DownloadItem, updateJob: Bool = true) {
		if updateJob {
			JobsManager.shared.cancel("browser-download.\(item.id.uuidString)")
			return
		}
        urlSession.getAllTasks { tasks in
            if let task = tasks.first(where: { task in
                self._activeDownloadID(for: task.taskIdentifier) == item.id.uuidString
            }) {
                task.cancel()
            }
        }
    }

	private func _setActiveDownload(_ id: String, for taskIdentifier: Int) {
		activeDownloadsLock.lock()
		activeDownloads[taskIdentifier] = id
		activeDownloadsLock.unlock()
	}

	private func _activeDownloadID(for taskIdentifier: Int) -> String? {
		activeDownloadsLock.lock()
		defer { activeDownloadsLock.unlock() }
		return activeDownloads[taskIdentifier]
	}

	private func _removeActiveDownload(for taskIdentifier: Int) {
		activeDownloadsLock.lock()
		activeDownloads.removeValue(forKey: taskIdentifier)
		activeDownloadsLock.unlock()
	}

	private func _downloadItem(id: String) -> DownloadItem? {
		var item: DownloadItem?
		_onMain {
			item = self.downloadItems.first(where: { $0.id.uuidString == id })
		}
		return item
	}

	private func _onMain(_ operation: @escaping () -> Void) {
		if Thread.isMainThread {
			operation()
		} else {
			DispatchQueue.main.sync(execute: operation)
		}
	}
    
    func handleITMSServicesURL(_ url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let manifestURLString = queryItems.first(where: { $0.name == "url" })?.value,
              let manifestURL = URL(string: manifestURLString) else {
            completion(.failure(NSError(domain: "ITMSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid manifest URL"])))
            return
        }
        
        urlSession.dataTask(with: manifestURL) { [weak self] data, _, error in
            guard let self = self else { return }
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(NSError(domain: "ITMSError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data"]))); return }
            
            self.parseManifestPlist(data) { result in
                switch result {
                case .success(let url):
                    let filename = url.lastPathComponent.isEmpty ? "app.ipa" : url.lastPathComponent
                    self.startDownload(url: url, filename: filename)
                    completion(.success(filename))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func checkFileTypeAndDownload(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        if isIPAFile(url) {
            startDownload(url: url, filename: url.lastPathComponent)
            completion(.success(url.lastPathComponent))
        } else {
            completion(.failure(NSError(domain: "FileTypeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid file type"])))
        }
    }
    
    private func parseManifestPlist(_ data: Data, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let items = plist["items"] as? [[String: Any]],
               let firstItem = items.first,
               let assets = firstItem["assets"] as? [[String: Any]] {
                
                for asset in assets {
                    if let kind = asset["kind"] as? String, kind == "software-package",
                       let urlString = asset["url"] as? String,
                       let url = URL(string: urlString) {
                        completion(.success(url))
                        return
                    }
                }
            }
            completion(.failure(NSError(domain: "ManifestParseError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No IPA URL found"])))
        } catch {
            completion(.failure(error))
        }
    }
}

    // MARK: - URLSessionDownloadDelegate

extension IPADownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        guard
			let downloadItemID = _activeDownloadID(for: downloadTask.taskIdentifier),
			let item = _downloadItem(id: downloadItemID)
		else {
			return
		}
        
        do {
            if fileManager.fileExists(atPath: item.localPath.path) {
                try fileManager.removeItem(at: item.localPath)
            }
            try fileManager.moveItem(at: location, to: item.localPath)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var updatedItem = item
                updatedItem.isFinished = true
                updatedItem.progress = 1.0
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: item.localPath.path)[.size] as? Int64 {
                    updatedItem.totalBytes = fileSize
                    updatedItem.bytesDownloaded = fileSize
                }
                
                if let index = self.downloadItems.firstIndex(where: { $0.id == item.id }) {
                    self.downloadItems[index] = updatedItem
                }
                self._removeActiveDownload(for: downloadTask.taskIdentifier)
				JobsManager.shared.complete(
					"browser-download.\(item.id.uuidString)",
					detail: .localized("Saved to Downloads")
				)
            }
        } catch {
            print("Error saving downloaded file: \(error)")
            DispatchQueue.main.async { [weak self] in
				if let index = self?.downloadItems.firstIndex(where: { $0.id == item.id }) {
					self?.downloadItems.remove(at: index)
				}
                self?._removeActiveDownload(for: downloadTask.taskIdentifier)
				JobsManager.shared.fail(
					"browser-download.\(item.id.uuidString)",
					error: error,
					detail: .localized("Download failed")
				)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let downloadItemID = _activeDownloadID(for: downloadTask.taskIdentifier) else { return }
        
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        
        DispatchQueue.main.async { [weak self] in
            guard
				let self,
				let index = self.downloadItems.firstIndex(where: { $0.id.uuidString == downloadItemID })
			else {
				return
			}
            var item = self.downloadItems[index]
            item.progress = progress
            item.bytesDownloaded = totalBytesWritten
            item.totalBytes = totalBytesExpectedToWrite
            self.downloadItems[index] = item
			JobsManager.shared.update(
				"browser-download.\(item.id.uuidString)",
				progress: progress,
				detail: item.progressText
			)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            guard let downloadItemID = _activeDownloadID(for: task.taskIdentifier) else { return }
            
            DispatchQueue.main.async { [weak self] in
				if let index = self?.downloadItems.firstIndex(where: { $0.id.uuidString == downloadItemID }) {
					self?.downloadItems.remove(at: index)
				}
                self?._removeActiveDownload(for: task.taskIdentifier)
				if (error as NSError).code != NSURLErrorCancelled {
					JobsManager.shared.fail(
						"browser-download.\(downloadItemID)",
						error: error,
						detail: .localized("Download failed")
					)
				}
            }
        }
        _removeActiveDownload(for: task.taskIdentifier)
    }
}
