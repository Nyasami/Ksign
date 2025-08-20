//
//  UnlockView.swift
//  Ksign
//
//  Created by AI Assistant on 2025.
//

import SwiftUI
import NimbleViews
import AltSourceKit

struct UnlockView: View {
    @ObservedObject private var unlockService = UnlockService.shared
    @Environment(\.dismiss) private var dismiss

    let source: ASRepository

    @State private var unlockCode = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var shouldAutoDismiss = false
    @State private var showUDIDAlert = false
    @State private var isRefreshing = false

    var body: some View {
        NBNavigationView(.localized("解锁软件源"), displayMode: .inline) {
            Form {
                // 顶部提示
                if !unlockService.unlockMessage.isEmpty {
                    Section {
                        Text(unlockService.unlockMessage)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 4)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    unlockService.unlockMessage = ""
                                }
                            }
                    }
                }

                // 输入框
                Section {
                    TextField(.localized("请输入解锁码"), text: $unlockCode)
                        .textFieldStyle(.automatic)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                } footer: {
                    Text(.localized("输入解锁码以获取完整软件源数据"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 按钮区域
                Section {
                    Button(unlockService.isUnlocking || isRefreshing ? "验证中..." : "解锁", systemImage: "lock.open") {
                        Task { await unlockSource() }
                    }
                    .disabled(unlockCode.isEmpty || unlockService.isUnlocking || isRefreshing)

                    if let payURL = source.payURL {
                        Button("购买解锁码", systemImage: "cart") {
                            openPayURL(payURL)
                        }
                    }
                } footer: {
                    Text(.localized("解锁后可获取完整的软件源数据"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toolbar {
                NBToolbarButton(role: .cancel)
                
                if unlockService.isUnlocking || isRefreshing {
                    ToolbarItem(placement: .confirmationAction) {
                        ProgressView()
                    }
                }
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定") {
                if shouldAutoDismiss { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .alert("获取 UDID", isPresented: $showUDIDAlert) {
            Button("获取 UDID") {
                if let url = URL(string: "https://app.yhios.cn/udid") {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请先获取 UDID 才能使用解锁功能")
        }
    }

    // MARK: - 解锁逻辑
    private func unlockSource() async {
        guard unlockService.hasValidUDID() else {
            showAlertWithUDIDLink("请先获取 UDID")
            return
        }
        guard let unlockURL = source.unlockURL else {
            showAlert("解锁URL无效")
            return
        }
        let success = await unlockService.unlockSource(unlockURL: unlockURL, code: unlockCode)
        if success {
            // 解锁成功后，自动刷新并关闭
            await refreshSourceData(autoDismiss: true)
        }
    }

    // MARK: - 刷新逻辑
    private func refreshSourceData(autoDismiss: Bool = false) async {
        guard let unlockURL = source.unlockURL else {
            showAlert("解锁URL无效")
            return
        }

        await MainActor.run { isRefreshing = true }

        if let data = await unlockService.fetchSourceDataWithUDIDCheck(unlockURL: unlockURL),
           let updatedSource = try? JSONDecoder().decode(ASRepository.self, from: data) {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("sourceRefreshed"),
                    object: nil,
                    userInfo: ["sourceId": source.id ?? "", "updatedSource": updatedSource]
                )
                showAlert("软件源刷新成功！", autoDismiss: autoDismiss)
            }
        } else {
            await MainActor.run {
                showAlert("刷新失败，请先获取UDID")
            }
        }

        await MainActor.run { isRefreshing = false }
    }

    // MARK: - 跳转支付
    private func openPayURL(_ url: URL) {
        UIApplication.shared.open(url)
    }

    // MARK: - 弹窗封装
    private func showAlert(_ message: String, autoDismiss: Bool = false) {
        alertMessage = message
        shouldAutoDismiss = autoDismiss
        showAlert = true
    }

    private func showAlertWithUDIDLink(_ message: String) {
        showUDIDAlert = true
    }
}