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
    @Binding var hexEditorFileURL: URL?
    @Binding var shareItems: [Any]
    @Binding var showingShareSheet: Bool
    @Binding var moveFileItem: FileItem?
    
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
        hexEditorFileURL: Binding<URL?>,
        shareItems: Binding<[Any]>,
        showingShareSheet: Binding<Bool>,
        moveFileItem: Binding<FileItem?>,
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
        self._hexEditorFileURL = hexEditorFileURL
        self._shareItems = shareItems
        self._showingShareSheet = showingShareSheet
        self._moveFileItem = moveFileItem
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
            if viewModel.isEditMode == .inactive {
                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
            else {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 22))
                }
                else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 22))
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
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
        .contextMenu {
            fileConfirmationDialogButtons()
        }
    }
    
    @ViewBuilder
    private func fileConfirmationDialogButtons() -> some View {
        if !file.isDirectory {
            Button {
                onPresentQuickLook(file)
            } label: {
                Label(String(localized: "Preview"), systemImage: "eye")
            }
            .tint(.primary)
        }
        
        if file.isPlistFile {
            Button {
                plistFileURL = file.url
            } label: {
                Label(String(localized: "Plist Editor"), systemImage: "list.bullet")
            }
            .tint(.primary)
        }
        
        if !file.isDirectory {
            Button {
                hexEditorFileURL = file.url
            } label: {
                Label(String(localized: "Hex Editor"), systemImage: "doc.text")
            }
            .tint(.primary)
        }
        
        if file.isP12Certificate {
            Button {
                viewModel.importCertificate(file)
            } label: {
                Label(String(localized: "Import Certificate"), systemImage: "key")
            }
            .tint(.primary)
        }
        
        if file.isKsignFile {
            Button {
                viewModel.importKsignFile(file)
            } label: {
                Label(String(localized: "Import Certificate"), systemImage: "key")
            }
            .tint(.primary)
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "ipa" {
            Button {
                onImportIpa(file)
            } label: {
                Text(String(localized: "Import to Library"))
                Image(systemName: "square.grid.2x2.fill")
            }
            .tint(.primary)
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "app" {
            Button {
                onPackageApp(file)
            } label: {
                Label(String(localized: "Package as IPA"), systemImage: "doc.zipper")
            }
            .tint(.primary)
        }
        
        if file.isArchive {
            Button {
                onExtractArchive(file)
            } label: {
                Label(String(localized: "Extract"), systemImage: "doc.zipper")
            }
            .tint(.primary)
        }

        Button {
            moveFileItem = file
        } label: {
            Label(String(localized: "Move"), systemImage: "folder")
        }
        .tint(.primary)
        
        Button {
            viewModel.itemToRename = file
            viewModel.newFileName = file.name
            viewModel.showRenameDialog = true
        } label: {
            Label(String(localized: "Rename"), systemImage: "pencil")
        }
        .tint(.primary)
        
        Button {
            file.url.startAccessingSecurityScopedResource()
            shareItems = [file.url]
            showingShareSheet = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                file.url.stopAccessingSecurityScopedResource()
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
        }
        .tint(.primary)
        
        Button(role: .destructive) {
            viewModel.deleteFile(file)
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
        .tint(.red)
    }
}
