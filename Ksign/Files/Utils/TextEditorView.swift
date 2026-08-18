//
//  TextEditorView.swift
//  Ksign
//
//  Created by Nagata Asami on 10/10/25.
//

import SwiftUI

struct TextEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var _text: String = ""
    @State private var _isChanged: Bool = false
    var body: some View {
        NavigationStack {
            TextEditor(text: $_text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 12, design: .monospaced))
                .navigationTitle(fileURL.lastPathComponent).navigationBarTitleDisplayMode(.inline)
                .toolbar { 
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Save")) { _saveFile() }
                            .disabled(!_isChanged)
                    }
                }
        }
        .onAppear(perform: _loadFile)
        .onChange(of: _text) { _ in
            _isChanged = true
        }
    }

    private func _loadFile() {
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            _text = contents
        } catch {
            print("Error loading file: \(error.localizedDescription)")
        }
    }

    private func _saveFile() {
        do {
            try _text.data(using: .utf8)?.write(to: fileURL)
            _isChanged = false
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
}

