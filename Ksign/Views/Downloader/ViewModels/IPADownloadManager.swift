//
//  IPADownloadManager.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

class IPADownloadManager: NSObject, ObservableObject {
    @Published var downloadItems: [DownloadItem] = []
    
    private var urlSession: URLSession!
    var activeDownloads: [Int: String] = [:] // taskIdentifier -> downloadItem.id
    
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
    
    private func cleanupStuckDownloads() {
        let stuckDownloads = downloadItems.filter { !$0.isFinished && $0.progress == 0 }
        
        if !stuckDownloads.isEmpty {
            downloadItems.removeAll { !$0.isFinished && $0.progress == 0 }
        }
        
        activeDownloads.removeAll()
    }
    
    func getDownloadDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("IPADownloads")
    }
    
    func loadDownloadedIPAs() {
        let downloadDirectory = getDownloadDirectory()
        
        cleanupStuckDownloads()
        
        let activeDownloads = downloadItems.filter { !$0.isFinished }
        downloadItems.removeAll()
        
        downloadItems.append(contentsOf: activeDownloads)
        
        do {
            try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let fileURLs = try FileManager.default.contentsOfDirectory(at: downloadDirectory, includingPropertiesForKeys: [.fileSizeKey], options: [])
            
            for fileURL in fileURLs {
                if fileURL.pathExtension.lowercased() == "ipa" {
                    if activeDownloads.contains(where: { $0.localPath == fileURL }) {
                        continue
                    }
                    
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
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
    
    func downloadIPA(url: URL, filename: String) {
        let downloadDirectory = getDownloadDirectory()
        try? FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        
        let destinationURL = downloadDirectory.appendingPathComponent(filename)
        let item = DownloadItem(
            title: filename,
            url: url,
            localPath: destinationURL,
            isFinished: false,
            progress: 0,
            totalBytes: 0,
            bytesDownloaded: 0
        )
        
        DispatchQueue.main.async {
            self.downloadItems.append(item)
        }
        
        let task = urlSession.downloadTask(with: url)
        
        activeDownloads[task.taskIdentifier] = item.id.uuidString
        
        task.resume()
    }
    
    func deleteIPA(at indexSet: IndexSet) {
        for index in indexSet {
            guard index < downloadItems.count else { continue }
            
            let item = downloadItems[index]
            
            if item.isFinished {
                do {
                    try FileManager.default.removeItem(at: item.localPath)
                    downloadItems.remove(at: index)
                } catch {
                    print("Failed to delete IPA: \(error)")
                }
            } else {
                if let taskId = activeDownloads.first(where: { $0.value == item.id.uuidString })?.key {
                    urlSession.getAllTasks { tasks in
                        for task in tasks {
                            if task.taskIdentifier == taskId {
                                task.cancel()
                                break
                            }
                        }
                    }
                    activeDownloads.removeValue(forKey: taskId)
                }
                downloadItems.remove(at: index)
            }
        }
    }
    
    func isFileURL(_ url: URL) -> Bool {    
        let fileExtensions = [
            "ipa", "zip", "pdf", "mp3", "mp4", "mov", "doc", "docx", "xls", "xlsx", 
            "ppt", "pptx", "pages", "numbers", "key", "apk", "dmg", "exe", 
            "app", "pkg", "deb", "rpm", "tar", "gz", "7z", "rar"
        ]
        
        let lastPathComponent = url.lastPathComponent.lowercased()
        
        if lastPathComponent.contains(".") {
            for ext in fileExtensions {
                if lastPathComponent.hasSuffix(".\(ext)") {
                    return true
                }
            }
        }
        
        return false
    }
    
    func parseManifestPlist(_ data: Data, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let items = plist["items"] as? [[String: Any]],
                  let firstItem = items.first,
                  let assets = firstItem["assets"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "ManifestParseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid manifest format"])))
                return
            }
            
            for asset in assets {
                if let kind = asset["kind"] as? String, kind == "software-package",
                   let urlString = asset["url"] as? String,
                   let url = URL(string: urlString) {
                    completion(.success(url))
                    return
                }
            }
            
            completion(.failure(NSError(domain: "ManifestParseError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No IPA download URL found in manifest"])))
            
        } catch {
            completion(.failure(error))
        }
    }
    
    func handleITMSServicesURL(_ url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let manifestURLString = queryItems.first(where: { $0.name == "url" })?.value,
              let manifestURL = URL(string: manifestURLString) else {
            completion(.failure(NSError(domain: "ITMSError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid manifest URL in itms-services link"])))
            return
        }
        
        let task = urlSession.dataTask(with: manifestURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ITMSError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received from manifest URL"])))
                return
            }
            
            self.parseManifestPlist(data) { result in
                switch result {
                case .success(let url):
                    let filename = url.lastPathComponent.isEmpty ? "app.ipa" : url.lastPathComponent
                    
                    self.downloadIPA(url: url, filename: filename)
                    completion(.success(filename))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func checkFileTypeAndDownload(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15 
        
        urlSession.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "DownloadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(.failure(error))
                return
            }
            
            if httpResponse.statusCode >= 300 {
                let error = NSError(domain: "DownloadError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code: \(httpResponse.statusCode)"])
                completion(.failure(error))
                return
            }
            
            let contentType = httpResponse.allHeaderFields["Content-Type"] as? String ?? ""
            
            var filename = url.lastPathComponent
            
            if !filename.contains(".") || filename.isEmpty {
                if contentType.contains("application/octet-stream") || 
                   contentType.contains("application/zip") ||
                   contentType.contains("application/x-zip") {
                    filename = "download.ipa"
                } else if contentType.contains("application/pdf") {
                    filename = "download.pdf"
                } else if contentType.contains("audio/") {
                    filename = "download.mp3"
                } else if contentType.contains("video/") {
                    filename = "download.mp4"
                } else if contentType.contains("image/jpeg") {
                    filename = "download.jpg"
                } else if contentType.contains("image/png") {
                    filename = "download.png"
                } else {
                    filename = "download.bin"
                }
            }
            
            self.downloadIPA(url: url, filename: filename)
            completion(.success(filename))
        }.resume()
    }
} 