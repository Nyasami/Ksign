 //
//  FirstLaunchPrivacyView.swift
//  Ksign
//
//  Created by AI Assistant on 2025.
//

import SwiftUI

struct FirstLaunchPrivacyView: View {
    @State private var hasAgreed = false
    @StateObject var downloadManager = DownloadManager.shared
    
    var body: some View {
        Group {
            if hasAgreed {
                // 用户已同意，显示主应用内容
                VStack {
                    DownloadHeaderView(downloadManager: downloadManager)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    VariedTabbarView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                .animation(.smooth, value: downloadManager.manualDownloads.description)
            } else {
                // 显示隐私协议
                PrivacyPolicyView(
                    isFirstLaunch: true,
                    onAgree: {
                        hasAgreed = true
                    }
                )
            }
        }
        .onAppear {
            // 检查用户是否已经同意过
            if UserDefaults.standard.bool(forKey: "hasAgreedToPrivacyPolicy") {
                hasAgreed = true
            }
        }
    }
}

#Preview {
    FirstLaunchPrivacyView()
}