//
//  FileItem.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import Foundation
import UIKit

struct FileItem: Identifiable, Hashable {
    var id: String { url.path }
    let name: String
    let url: URL
    let size: Int64
    let creationDate: Date?
    let isDirectory: Bool
    
    var fileExtension: String? {
        return url.pathExtension.isEmpty ? nil : url.pathExtension
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var isArchive: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ["zip", "ipa", "deb"].contains(ext)
    }
    
    var isP12Certificate: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "p12"
    }
    
    var isKsignFile: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "ksign"
    }
    
    var isZipArchive: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ["zip", "ipa"].contains(ext)
    }
    
    var isDebArchive: Bool {
        guard let ext = fileExtension?.lowercased() else { return false }
        return ext == "deb"
    }
    
    var isAppDirectory: Bool {
        return isDirectory && fileExtension?.lowercased() == "app"
    }
    
    var isPlistFile: Bool {
        guard !isDirectory, let ext = fileExtension?.lowercased() else { return false }
        return ext == "plist"
    }
    
    var isImageFile: Bool {
        guard !isDirectory else { return false }
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic"]
        return imageExtensions.contains(fileExtension?.lowercased() ?? "")
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url
    }
} 
