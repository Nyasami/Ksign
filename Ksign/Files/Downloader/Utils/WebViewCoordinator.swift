//
//  WebViewCoordinator.swift
//  Ksign
//
//  Created by Nagata Asami on 5/24/25.
//

import SwiftUI
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    private var parent: WebViewContainer
    
    init(_ parent: WebViewContainer) {
        self.parent = parent
        super.init()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if handleSpecialURL(url) {
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if handleSpecialURL(url) {
                return nil
            }
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    private func handleSpecialURL(_ url: URL) -> Bool {
        if url.scheme == "itms-services" {
            parent.handleITMSURL(url)
            return true
        }
        
        if parent.downloadManager.isIPAFile(url) {
            parent.downloadDirectFile(url)
            return true
        }
        
        return false
    }
    
    private func handleNavigationError(_ error: Error) {
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        
        UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
    }
}
