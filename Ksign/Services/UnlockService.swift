//
//  UnlockService.swift
//  Ksign
//
//  Created by AI Assistant on 2025.
//

import Foundation
import Combine
import UIKit

class UnlockService: ObservableObject {
    static let shared = UnlockService()
    
    @Published var isUnlocking = false
    @Published var unlockMessage = ""
    
    private init() {}
    
    // 获取 UDID
    func getUDID() -> String {
        // 首先尝试从本地存储获取
        if let savedUDID = UserDefaults.standard.string(forKey: "deviceUDID"), !savedUDID.isEmpty {
            return savedUDID
        }
        
        // 尝试从 embedded.mobileprovision 获取
        if let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            let url = URL(fileURLWithPath: path)
            let reader = CertificateReader(url)
            if let devices = reader.decoded?.ProvisionedDevices, devices.count == 1 {
                let udid = devices[0]
                UserDefaults.standard.set(udid, forKey: "deviceUDID")
                return udid
            }
        }
        
        // 如果都没有，返回空字符串而不是生成新的
        return ""
    }
    
    // 检查是否有有效的 UDID
    func hasValidUDID() -> Bool {
        // 检查本地存储
        if let savedUDID = UserDefaults.standard.string(forKey: "deviceUDID"), !savedUDID.isEmpty {
            return true
        }
        
        // 检查 embedded.mobileprovision
        if let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            let url = URL(fileURLWithPath: path)
            let reader = CertificateReader(url)
            if let devices = reader.decoded?.ProvisionedDevices, devices.count == 1 {
                return true
            }
        }
        
        return false
    }
    
    // 验证卡密
    func unlockSource(unlockURL: URL, code: String) async -> Bool {
        let udid = getUDID()
        let urlString = "\(unlockURL.absoluteString)?udid=\(udid)&code=\(code)"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.unlockMessage = "无效的解锁URL"
            }
            return false
        }
        
        await MainActor.run {
            self.isUnlocking = true
            self.unlockMessage = "正在验证卡密..."
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(UnlockResponse.self, from: data)
            
            await MainActor.run {
                self.isUnlocking = false
                self.unlockMessage = response.msg
            }
            
            let success = response.code == 0 && response.msg.contains("解锁成功")
            
            // 如果解锁成功，发送通知
            if success {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("sourceUnlocked"),
                        object: nil,
                        userInfo: ["sourceId": unlockURL.host ?? ""]
                    )
                }
            }
            
            return success
        } catch {
            await MainActor.run {
                self.isUnlocking = false
                self.unlockMessage = "网络错误: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // 获取软件源数据（带 UDID 检查）
    func fetchSourceDataWithUDIDCheck(unlockURL: URL) async -> Data? {
        guard hasValidUDID() else {
            return nil
        }
        
        let udid = getUDID()
        let urlString = "\(unlockURL.absoluteString)?udid=\(udid)"
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
}

// 解锁响应模型
struct UnlockResponse: Codable {
    let code: Int
    let msg: String
} 