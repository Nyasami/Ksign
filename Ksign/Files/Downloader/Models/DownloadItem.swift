//
//  DownloadItem.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI

struct DownloadItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let localPath: URL
    var isFinished: Bool
    var progress: Double
    var totalBytes: Int64
    var bytesDownloaded: Int64

    var formattedFileSize: String {
        return totalBytes.formattedByteCount
    }
    
    var progressText: String {
        let downloadedStr = bytesDownloaded.formattedByteCount
        let totalStr = totalBytes.formattedByteCount
        return "\(downloadedStr) / \(totalStr) (\(Int(progress * 100))%)"
    }
} 