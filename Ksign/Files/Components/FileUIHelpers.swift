//
//  FileUIHelpers.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileUIHelpers {
    
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
            UIAlertController.showAlertWithTextBox(
                title: .localized("Rename"),
                message: .localized("Enter a new name"),
                textFieldPlaceholder: .localized("File name"),
                textFieldText: file.name,
                submit: .localized("Rename"),
                cancel: .localized("Cancel"),
                onSubmit: { name in
                    viewModel.renameFile(newName: name, item: file)
                }
            )
        } label: {
            Label(String(localized: "Rename"), systemImage: "pencil")
        }
        .tint(.blue)
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
} 
