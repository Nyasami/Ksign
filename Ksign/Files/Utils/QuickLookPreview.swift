//
//  QuickLookPreview.swift
//  Ksign
//
//  Created by Nagata Asami on 11/10/25.
//

import SwiftUI
import QuickLook
import UIKit


struct QuickLookPreview: UIViewControllerRepresentable {
    let fileURL: URL

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let _fileURL: URL
        init(fileURL: URL) {
            self._fileURL = fileURL
        }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            _fileURL as QLPreviewItem
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(fileURL: fileURL) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: ql)
        // nav.modalPresentationStyle = .fullScreen
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let ql = uiViewController.viewControllers.first as? QLPreviewController {
            ql.reloadData()
        }
    }
}
