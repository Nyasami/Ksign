//
//  WebViewContainer.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var downloadManager: IPADownloadManager
    var url: URL
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        config.processPool = WKProcessPool()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates happen through bindings and coordinator
    }
    
    func handleITMSURL(_ url: URL) {
        downloadManager.handleITMSServicesURL(url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    UIAlertController.showAlertWithOk(title: .localized("Success"), message: .localized("The IPA file is being downloaded!\nYou can close this window or download more!"))
                case .failure(let error):
                    UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
                }
            }
        }
    }
    
    func downloadDirectFile(_ url: URL) {
        downloadManager.checkFileTypeAndDownload(url: url) { result in
            switch result {
            case .success:
                UIAlertController.showAlertWithOk(title: .localized("Success"), message: .localized("The IPA file is being downloaded!\nYou can close this window or download more!"))
            case .failure(let error):
                UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
            }
        }
    }
}
