//
//  FileExporterRepresentableView.swift
//  NimbleViews
//
//  Created by Nagata Asami on 14/8/25.
//

import SwiftUI

public struct FileExporterRepresentableView: UIViewControllerRepresentable {
    public var urlsToExport: [URL]
    public var asCopy: Bool
    public var useLastLocation: Bool
    public var onCompletion: (Bool) -> Void

    public init(
        urlsToExport: [URL],
        asCopy: Bool = false,
        useLastLocation: Bool = false,
        onCompletion: @escaping (Bool) -> Void
    ) {
        self.urlsToExport = urlsToExport
        self.asCopy = asCopy
        self.useLastLocation = useLastLocation
        self.onCompletion = onCompletion
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: urlsToExport, asCopy: asCopy)
        picker.delegate = context.coordinator
        picker.directoryURL = !useLastLocation ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first : nil
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onCompletion: (Bool) -> Void

        init(onCompletion: @escaping (Bool) -> Void) {
            self.onCompletion = onCompletion
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onCompletion(true)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(false)
        }
    }
}

