//
//  FileUIHelpers.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileUIHelpers {
    
    // MARK: - Selection Background
    
    static func selectionBackground(for file: FileItem, selectedItems: Set<FileItem>) -> some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(selectedItems.contains(file) ? .accentColor.opacity(0.1) : Color.clear)
            .padding(.horizontal, 4)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedItems.contains(file))
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    static func swipeActions(for file: FileItem, viewModel: FilesViewModel) -> some View {
        Button(role: .destructive) {
            withAnimation {
                viewModel.deleteFile(file)
            }
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
        
        Button {
            viewModel.itemToRename = file
            viewModel.newFileName = file.name
            viewModel.showRenameDialog = true
        } label: {
            Label(String(localized: "Rename"), systemImage: "pencil")
        }
        .tint(.blue)
    }
    
    // MARK: - File Sharing
    
    static func shareFile(_ file: FileItem, shareItems: Binding<[Any]>, showingShareSheet: Binding<Bool>) {
        let didStartAccessing = file.url.startAccessingSecurityScopedResource()
        
        shareItems.wrappedValue = [file.url]
        showingShareSheet.wrappedValue = true
        
        if didStartAccessing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                file.url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    // MARK: - File Tap Handling
    
    static func handleFileTap(
        _ file: FileItem,
        viewModel: FilesViewModel,
        selectedFileForAction: Binding<FileItem?>,
        showingActionSheet: Binding<Bool>
    ) {
        if viewModel.isEditMode == .active {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if viewModel.selectedItems.contains(file) {
                    viewModel.selectedItems.remove(file)
                } else {
                    viewModel.selectedItems.insert(file)
                }
            }
        } else {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            selectedFileForAction.wrappedValue = file
            showingActionSheet.wrappedValue = true
        }
    }
    
    // MARK: - Progress View
    
    static func extractionProgressView(progress: Double) -> some View {
        VStack {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
            
            Text(String(localized: "Extracting \(Int(progress * 100))%"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 5)
        )
        .transition(.scale.combined(with: .opacity))
    }
} 
