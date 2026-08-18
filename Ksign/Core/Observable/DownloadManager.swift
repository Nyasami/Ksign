//
//  enum.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import Foundation
import Combine
import UIKit.UIImpactFeedbackGenerator
import SwiftUI // For ByteCountFormatter
import UserNotifications

// Import the error handlers module
@_exported import class UIKit.UIImpactFeedbackGenerator

class Download: Identifiable, @unchecked Sendable, ObservableObject {
	@Published var progress: Double = 0.0
	@Published var bytesDownloaded: Int64 = 0
	@Published var totalBytes: Int64 = 0
	@Published var unpackageProgress: Double = 0.0
	
	var overallProgress: Double {
		onlyArchiving
		? unpackageProgress
		: (0.3 * unpackageProgress) + (0.7 * progress)
	}

	var formattedFileSize: String {
		return totalBytes.formattedByteCount
	}
	
	var progressText: String {
		if unpackageProgress > 0 {
			return "\(Int(unpackageProgress * 100))%"
		}
		let downloadedStr = bytesDownloaded.formattedByteCount
		let totalStr = totalBytes.formattedByteCount
		return "\(downloadedStr) / \(totalStr) (\(Int(progress * 100))%)"
	}
    var task: URLSessionDownloadTask?
    var resumeData: Data?
	
	let id: String
	let url: URL
	let fileName: String
	let onlyArchiving: Bool
    
    init(
		id: String,
		url: URL,
		onlyArchiving: Bool = false
	) {
		self.id = id
        self.url = url
		self.onlyArchiving = onlyArchiving
        self.fileName = url.lastPathComponent
    }
}

class DownloadManager: NSObject, ObservableObject {
	static let shared = DownloadManager()
	
    @Published var downloads: [Download] = []
	
	var manualDownloads: [Download] {
		downloads.filter { isManualDownload($0.id) }
	}
	
    private var _session: URLSession!
    
    private func _updateBackgroundAudioState() {
        if #unavailable(iOS 26.0){
            if !downloads.isEmpty {
                BackgroundAudioManager.shared.start()
            } else  {
                BackgroundAudioManager.shared.stop()
            }
        }
    }
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        _session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    func startDownload(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
        if let existingDownload = downloads.first(where: { $0.url == url }) {
            resumeDownload(existingDownload)
            return existingDownload
        }
        print(id)
		let download = Download(id: id, url: url)
        
        let task = _session.downloadTask(with: url)
        download.task = task
        task.resume()
        
        downloads.append(download)
		if #available(iOS 26.0, *) {
			BackgroundTaskManager.shared.startTask(for: id, filename: url.lastPathComponent)
		} else {
			_updateBackgroundAudioState()
		}
        return download
    }
	
	func startArchive(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
		let download = Download(id: id, url: url, onlyArchiving: true)
		downloads.append(download)
		_updateBackgroundAudioState()
		return download
	}
    
    func resumeDownload(_ download: Download) {
        if let resumeData = download.resumeData {
            let task = _session.downloadTask(withResumeData: resumeData)
            download.task = task
            task.resume()
            _updateBackgroundAudioState()
        } else if let url = download.task?.originalRequest?.url {
            let task = _session.downloadTask(with: url)
            download.task = task
            task.resume()
            _updateBackgroundAudioState()
        }
    }
    
    func cancelDownload(_ download: Download) {
        download.task?.cancel()
        
        if let index = downloads.firstIndex(where: { $0.id == download.id }) {
            downloads.remove(at: index)
            _updateBackgroundAudioState()
            if #available(iOS 26.0, *) {
                BackgroundTaskManager.shared.stopTask(for: download.id, success: false)
            }
        }
    }
    
	func isManualDownload(_ string: String) -> Bool {
		return string.contains("FeatherManualDownload")
	}
	
	func getDownload(by id: String) -> Download? {
		return downloads.first(where: { $0.id == id })
	}
	
	func getDownloadIndex(by id: String) -> Int? {
		return downloads.firstIndex(where: { $0.id == id })
	}
	
	func getDownloadTask(by task: URLSessionDownloadTask) -> Download? {
		return downloads.first(where: { $0.task == task })
	}
}

extension DownloadManager: URLSessionDownloadDelegate {
	
	func handlePachageFile(
		url: URL,
		dl: Download?,
		completion: @escaping (Error?) -> Void
	) {
		FR.handlePackageFile(url, download: dl) { err in
			if let error = err {
				let generator = UINotificationFeedbackGenerator()
				generator.notificationOccurred(.error)
				print("Package handling error: \(error.localizedDescription)")
				if let nsError = error as? NSError {
					if nsError.domain == NSPOSIXErrorDomain && nsError.code == 28 {
						print("No space left on device")
					} else if nsError.domain == NSCocoaErrorDomain {
						print("Cocoa error: \(nsError.localizedDescription)")
					}
				}
				let errorString = String(describing: error)
				if errorString.contains("notEnoughDiskSpace") {
					print("Not enough disk space for extraction")
				} else if errorString.contains("payloadNotFound") {
					print("Payload folder not found in archive")
				}
			}
			DispatchQueue.main.async {
				if let dl = dl, let index = DownloadManager.shared.getDownloadIndex(by: dl.id) {
					DownloadManager.shared.downloads.remove(at: index)
				}
				if err == nil {
					self._notifyDownloadCompleted(fileName: url.lastPathComponent)
				}
				completion(err)
			}
		}
	}

	func handlePachageFile(url: URL, dl: Download?) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			self.handlePachageFile(url: url, dl: dl) { err in
				if let error = err {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let download = getDownloadTask(by: downloadTask) else { return }
		
		var downloadDir: URL
		if !OptionsManager.shared.options.saveAppStoreDownloadsToDownloadsFolder {
			let tempDirectory = FileManager.default.temporaryDirectory
			downloadDir = tempDirectory.appendingPathComponent("FeatherDownloads", isDirectory: true)
		} else {
			downloadDir = URL.documentsDirectory.appendingPathComponent("Downloads")
		}
		
		do {
			try FileManager.default.createDirectoryIfNeeded(at: downloadDir)
			let suggestedFileName = downloadTask.response?.suggestedFilename ?? download.fileName
			let destinationURL = downloadDir.appendingPathComponent(suggestedFileName)
			try FileManager.default.removeFileIfNeeded(at: destinationURL)
			try FileManager.default.moveItem(at: location, to: destinationURL)
			self.handlePachageFile(url: destinationURL, dl: download) { err in
				if let error = err {
					print("Error handling downloaded file: \(error.localizedDescription)")
				}
			}
		} catch {
			print("Error handling downloaded file: \(error.localizedDescription)")
		}
	}
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let download = getDownloadTask(by: downloadTask) else { return }
        
        DispatchQueue.main.async {
            download.progress = totalBytesExpectedToWrite > 0
			? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
			: 0
            download.bytesDownloaded = totalBytesWritten
            download.totalBytes = totalBytesExpectedToWrite
            if #available(iOS 26.0, *) {
                BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard
			let _ = error,
			let downloadTask = task as? URLSessionDownloadTask,
			let download = getDownloadTask(by: downloadTask)
		else {
			return
		}
		
		DispatchQueue.main.async {
			if let index = self.getDownloadIndex(by: download.id) {
				self.downloads.remove(at: index)
			}
		}
    }
    
    
    private func _notifyDownloadCompleted(fileName: String) {
        guard OptionsManager.shared.options.notifications else { return }
        let content = UNMutableNotificationContent()
        content.title = String.localized("Download Completed")
        content.body = fileName
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "download.\(fileName)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule notification: \(error.localizedDescription)") }
        }
    }
}
