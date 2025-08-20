//
//  SourceUnlockManager.swift
//  Ksign
//
//  Created by AI Assistant on 2025.
//

import Foundation
import Combine
import AltSourceKit
import UIKit

class SourceUnlockManager: ObservableObject {
    static let shared = SourceUnlockManager()
    
    @Published var unlockedSources: Set<String> = []
    @Published var isRefreshing = false
    
    private let unlockService = UnlockService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - 解锁状态管理
    func isSourceUnlocked(_ sourceId: String) -> Bool {
        return unlockedSources.contains(sourceId)
    }
    func markSourceAsUnlocked(_ sourceId: String) {
        unlockedSources.insert(sourceId)
    }
    func removeUnlockStatus(_ sourceId: String) {
        unlockedSources.remove(sourceId)
    }
    func clearAllUnlockStatus() {
        unlockedSources.removeAll()
    }
    
    // MARK: - 自动刷新管理
    func refreshUnlockedSources(_ sources: [AltSource: ASRepository]) async {
        guard !isRefreshing else { return }
        await MainActor.run { isRefreshing = true }
        let unlockedSourceIds = Set(unlockedSources)
        let sourcesToRefresh = sources.filter { source, _ in
            unlockedSourceIds.contains(source.identifier ?? "")
        }
        for (altSource, repository) in sourcesToRefresh {
            if let unlockURL = repository.unlockURL {
                await refreshSingleSource(altSource: altSource, unlockURL: unlockURL)
            }
        }
        await MainActor.run { isRefreshing = false }
    }
    private func refreshSingleSource(altSource: AltSource, unlockURL: URL) async {
        guard unlockService.hasValidUDID() else { return }
        let udid = unlockService.getUDID()
        let urlString = "\(unlockURL.absoluteString)?udid=\(udid)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let updatedSource = try? JSONDecoder().decode(ASRepository.self, from: data) {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("sourceRefreshed"),
                        object: nil,
                        userInfo: [
                            "sourceId": altSource.identifier ?? "",
                            "updatedSource": updatedSource
                        ]
                    )
                }
            }
        } catch {
            // 静默处理错误
        }
    }
    
    // MARK: - 通知处理
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: Notification.Name("sourceUnlocked"))
            .sink { [weak self] notification in
                if let sourceId = notification.userInfo?["sourceId"] as? String {
                    self?.markSourceAsUnlocked(sourceId)
                }
            }
            .store(in: &cancellables)
    }
}

extension Notification.Name {
    static let sourceUnlocked = Notification.Name("sourceUnlocked")
}