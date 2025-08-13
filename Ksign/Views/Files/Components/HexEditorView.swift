//
//  HexEditorView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct HexEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = HexEditorViewModel()
    @State private var searchText = ""
    @State private var showingUnsavedAlert = false
    
    private enum ViewMode: Int, CaseIterable {
        case byte = 0
        case string = 1
        
        var title: String {
            switch self {
            case .byte: return "Byte"
            case .string: return "String"
            }
        }
    }
    
    @State private var currentViewMode: ViewMode = .byte
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            viewModeSegmentedControl
            searchBarView
            contentView
        }
        .onAppear {
            viewModel.loadFile(fileURL)
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedAlert) {
            Button("Save") {
                viewModel.saveChanges()
                dismiss()
            }
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to save them before closing?")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var headerView: some View {
        HStack {
            Button {
                if viewModel.hasUnsavedChanges {
                    showingUnsavedAlert = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            Text(fileURL.lastPathComponent)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                viewModel.toggleEditMode()
            } label: {
                Image(systemName: viewModel.isEditingMode ? "checkmark.circle.fill" : "pencil.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var viewModeSegmentedControl: some View {
        Picker("View Mode", selection: $currentViewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .disabled(viewModel.isEditingMode)
        .opacity(viewModel.isEditingMode ? 0.5 : 1.0)
    }
    
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search hex or ASCII", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        viewModel.performSearch(searchText)
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if viewModel.hasSearchResults {
                Button("Next") {
                    viewModel.nextSearchMatch()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .disabled(viewModel.isEditingMode)
        .opacity(viewModel.isEditingMode ? 0.5 : 1.0)
    }
    
    private var contentView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.isLoading {
                        ProgressView("Loading file...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        switch currentViewMode {
                            case .byte:
                                byteView
                            case .string:
                                stringView
                        }
                    }
                }
                .onChange(of: viewModel.scrollToIndex) { index in
                    if let index = index {
                        withAnimation {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
    }
    
    private var byteView: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(Array(viewModel.hexLines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: 0) {
                    Text(line.address)
                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.9))
                        .frame(width: 80, alignment: .leading)
                    
                    Text(line.hexBytes)
                        .foregroundColor(.primary)
                        .frame(width: 200, alignment: .leading)
                    
                    Text(line.asciiText)
                        .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.3))
                        .frame(alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(
                    viewModel.highlightedLineIndex == index ?
                    Color.yellow.opacity(0.3) : Color.clear
                )
                .id(index)
                .contentShape(Rectangle())
                .onTapGesture {
                    if viewModel.isEditingMode {
                        viewModel.selectByteForEditing(lineIndex: index)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var stringView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("String representation:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            Text(viewModel.stringRepresentation)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 16)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

@MainActor
class HexEditorViewModel: ObservableObject {
    @Published var hexLines: [HexLine] = []
    @Published var stringRepresentation: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEditingMode = false
    @Published var hasUnsavedChanges = false
    @Published var hasSearchResults = false
    @Published var highlightedLineIndex: Int?
    @Published var scrollToIndex: Int?
    
    private var fileURL: URL?
    private var fileData = Data()
    private var fileSize: Int = 0
    private let maxDisplayBytes = 10240 // 10KB at a time
    private var currentOffset = 0
    private var searchMatches: [Int] = []
    private var currentMatchIndex = -1
    
    struct HexLine {
        let address: String
        let hexBytes: String
        let asciiText: String
    }
    
    func loadFile(_ url: URL) {
        print("HexEditorViewModel.loadFile called with: \(url.path)")
        fileURL = url
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = fileAttributes[.size] as? NSNumber {
                    fileSize = size.intValue
            } else {
                    fileSize = 0
                }
                
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw HexEditorError.fileNotFound
                }
                
                let fileHandle = try FileHandle(forReadingFrom: url)
                defer { try? fileHandle.close() }
                
                try fileHandle.seek(toOffset: UInt64(currentOffset))
                fileData = fileHandle.readData(ofLength: min(maxDisplayBytes, fileSize - currentOffset))
                
                await MainActor.run {
                    _processFileData()
                    isLoading = false
                    print("HexEditorViewModel: Successfully loaded \(hexLines.count) lines")
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load file: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func saveChanges() {
        guard let fileURL = fileURL, hasUnsavedChanges else { return }
        
        Task {
            do {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                defer { try? fileHandle.close() }
                
                try fileHandle.seek(toOffset: UInt64(currentOffset))
                fileHandle.write(fileData)
                
                await MainActor.run {
                    hasUnsavedChanges = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func toggleEditMode() {
        isEditingMode.toggle()
        if !isEditingMode && hasUnsavedChanges {
            saveChanges()
        }
    }
    
    func selectByteForEditing(lineIndex: Int) {
        print("Selected line \(lineIndex) for editing")
    }
    
    func performSearch(_ searchText: String) {
        guard !searchText.isEmpty else {
            clearSearch()
            return
        }
        
        searchMatches.removeAll()
        currentMatchIndex = -1
        
        let content = _generateSearchableContent()
        let searchLower = searchText.lowercased()
        
        var searchIndex = content.startIndex
        while searchIndex < content.endIndex {
            if let range = content.range(of: searchLower, options: .caseInsensitive, range: searchIndex..<content.endIndex) {
                let lineIndex = _getLineIndex(for: range.lowerBound, in: content)
                searchMatches.append(lineIndex)
                searchIndex = range.upperBound
            } else {
                break
            }
        }
        
        hasSearchResults = !searchMatches.isEmpty
        if hasSearchResults {
            currentMatchIndex = 0
            _highlightSearchMatch()
        }
    }
    
    func nextSearchMatch() {
        guard hasSearchResults else { return }
        
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        _highlightSearchMatch()
    }
    
    func clearSearch() {
        searchMatches.removeAll()
        currentMatchIndex = -1
        hasSearchResults = false
        highlightedLineIndex = nil
        scrollToIndex = nil
    }
    
    // MARK: - Private Methods
    
    private func _processFileData() {
        hexLines.removeAll()
        
        var lines: [HexLine] = []
        var address = currentOffset
        
        for chunkStart in stride(from: 0, to: fileData.count, by: 8) {
            let chunkEnd = min(chunkStart + 8, fileData.count)
            let chunk = fileData[chunkStart..<chunkEnd]
            
            let addressString = String(format: "%08X", address)
            
            var hexBytes = ""
            var asciiText = ""
            
            for (index, byte) in chunk.enumerated() {
                if index > 0 { hexBytes += " " }
                hexBytes += String(format: "%02X", byte)
                
                let asciiChar = (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : "."
                asciiText += String(asciiChar)
            }
            
            // Pad hex bytes to consistent width
            while hexBytes.count < 23 { // 8 bytes * 2 hex chars + 7 spaces
                hexBytes += "   "
            }
            
            lines.append(HexLine(
                address: addressString,
                hexBytes: hexBytes,
                asciiText: asciiText
            ))
            
            address += 8
        }
        
        hexLines = lines
        _generateStringRepresentation()
    }
    
    private func _generateStringRepresentation() {
        var result = ""
        
        for byte in fileData {
            if byte >= 32 && byte <= 126 {
                result.append(Character(UnicodeScalar(byte)))
            } else if byte == 10 || byte == 13 {
                result.append("\n")
            } else {
                result.append(".")
            }
        }
        
        stringRepresentation = result
    }
    
    private func _generateSearchableContent() -> String {
        return hexLines.map { "\($0.address) \($0.hexBytes) \($0.asciiText)" }.joined(separator: "\n")
    }
    
    private func _getLineIndex(for position: String.Index, in content: String) -> Int {
        let substring = content[..<position]
        return substring.components(separatedBy: "\n").count - 1
    }
    
    private func _highlightSearchMatch() {
        guard currentMatchIndex >= 0 && currentMatchIndex < searchMatches.count else { return }
        
        let lineIndex = searchMatches[currentMatchIndex]
        highlightedLineIndex = lineIndex
        scrollToIndex = lineIndex
    }
}

enum HexEditorError: LocalizedError {
    case fileNotFound
    case readError
    case writeError
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .readError:
            return "Failed to read file"
        case .writeError:
            return "Failed to write file"
        }
    }
} 
