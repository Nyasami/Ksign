//
//  FileRow.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileRow: View {
    let file: FileItem
    let isSelected: Bool
    @ObservedObject var viewModel: FilesViewModel
    @Binding var plistFileURL: URL?
    @Binding var navigateToPlistEditor: Bool
    @Binding var hexEditorFileURL: URL?
    @Binding var navigateToHexEditor: Bool
    @Binding var shareItems: [Any]
    @Binding var showingShareSheet: Bool
    
    let onExtractArchive: (FileItem) -> Void
    let onPackageApp: (FileItem) -> Void
    let onImportIpa: (FileItem) -> Void
    let onPresentQuickLook: (FileItem) -> Void
    let onNavigateToDirectory: ((URL) -> Void)?
    
    init(
        file: FileItem, 
        isSelected: Bool, 
        viewModel: FilesViewModel,
        plistFileURL: Binding<URL?>,
        navigateToPlistEditor: Binding<Bool>,
        hexEditorFileURL: Binding<URL?>,
        navigateToHexEditor: Binding<Bool>,
        shareItems: Binding<[Any]>,
        showingShareSheet: Binding<Bool>,
        onExtractArchive: @escaping (FileItem) -> Void,
        onPackageApp: @escaping (FileItem) -> Void,
        onImportIpa: @escaping (FileItem) -> Void,
        onPresentQuickLook: @escaping (FileItem) -> Void,
        onNavigateToDirectory: ((URL) -> Void)? = nil
    ) {
        self.file = file
        self.isSelected = isSelected
        self.viewModel = viewModel
        self._plistFileURL = plistFileURL
        self._navigateToPlistEditor = navigateToPlistEditor
        self._hexEditorFileURL = hexEditorFileURL
        self._navigateToHexEditor = navigateToHexEditor
        self._shareItems = shareItems
        self._showingShareSheet = showingShareSheet
        self.onExtractArchive = onExtractArchive
        self.onPackageApp = onPackageApp
        self.onImportIpa = onImportIpa
        self.onPresentQuickLook = onPresentQuickLook
        self.onNavigateToDirectory = onNavigateToDirectory
    }
    
    @State private var isHovering = false
    @State private var showingConfirmationDialog = false
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if file.isDirectory {
                    if file.isAppDirectory {
                        Image(systemName: "app.badge")
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                    }
                } else if file.isImageFile {
                    ImageRow(file: file)
                } else if file.isArchive {
                    Image(systemName: "doc.zipper")
                        .foregroundColor(.accentColor)
                } else if file.isPlistFile {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.accentColor)
                } else if file.isP12Certificate {
                    Image(systemName: "key")
                        .foregroundColor(.accentColor)
                } else if file.isKsignFile {
                    Image(systemName: "signature")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "doc")
                        .foregroundColor(.accentColor)
                }
            }
            .font(.title2)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .animation(.spring(), value: file.isDirectory)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if !file.isDirectory {
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let date = file.creationDate {
                        if !file.isDirectory {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 22))
//                    .transition(.scale.combined(with: .opacity))
            }
            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if viewModel.isEditMode == .active {
                if viewModel.selectedItems.contains(file) {
                    viewModel.selectedItems.remove(file)
                } else {
                    viewModel.selectedItems.insert(file)
                }
            } else if file.isDirectory {
                onNavigateToDirectory?(file.url)
            } else {
                showingConfirmationDialog = true
            }
        }
        .confirmationDialog(
            file.name,
            isPresented: $showingConfirmationDialog,
            titleVisibility: .visible
        ) {
            fileConfirmationDialogButtons()
        }
    }
    
    @ViewBuilder
    private func fileConfirmationDialogButtons() -> some View {
        if !file.isDirectory {
            Button(String(localized: "Preview")) {
                onPresentQuickLook(file)
            }
        }
        
        if file.isPlistFile {
            Button(String(localized: "Plist Editor")) {
                plistFileURL = file.url
                navigateToPlistEditor = true
            }
        }
        
        if !file.isDirectory {
            Button(String(localized: "Hex Editor")) {
                hexEditorFileURL = file.url
                navigateToHexEditor = true
            }
        }
        
        if file.isP12Certificate {
            Button(String(localized: "Import Certificate")) {
                viewModel.importCertificate(file)
            }
        }
        
        if file.isKsignFile {
            Button(String(localized: "Import Certificate")) {
                viewModel.importKsignFile(file)
            }
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "ipa" {
            Button(String(localized: "Import to Library")) {
                onImportIpa(file)
            }
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "app" {
            Button(String(localized: "Package as IPA")) {
                onPackageApp(file)
            }
        }
        
        if file.isArchive {
            Button(String(localized: "Extract")) {
                onExtractArchive(file)
            }
        }
        
        Button(String(localized: "Rename")) {
            viewModel.itemToRename = file
            viewModel.newFileName = file.name
            viewModel.showRenameDialog = true
        }
        
        Button(String(localized: "Share")) {
            file.url.startAccessingSecurityScopedResource()
            shareItems = [file.url]
            showingShareSheet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                file.url.stopAccessingSecurityScopedResource()
            }
        }
        
        Button(String(localized: "Delete"), role: .destructive) {
            withAnimation {
                viewModel.deleteFile(file)
            }
        }
    }
}
