//
//  SourcesViewModel.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import Foundation
import AltSourceKit
import CoreData
import SwiftUI
import NimbleJSON

// MARK: - Class
final class SourcesViewModel: ObservableObject {
	static let shared = SourcesViewModel()
	
	typealias RepositoryDataHandler = Result<ASRepository, Error>
	
	private let _dataService = NBFetchService()
	
	@Published var isFinished = true
	@Published var sources: [AltSource: ASRepository] = [:]
	
	func fetchSources(_ sources: FetchedResults<AltSource>, refresh: Bool = false, batchSize: Int = 4) async {
		let preparation = await MainActor.run {
			() -> ([(objectID: NSManagedObjectID, url: URL?)], [NSManagedObjectID: AltSource])? in
			guard self.isFinished else { return nil }

			// Check if sources to be fetched are the same as before, unless a refresh was requested.
			if !refresh, sources.allSatisfy({ self.sources[$0] != nil }) {
				return nil
			}

			self.isFinished = false
			self.sources = [:]
			SourceIntelligenceManager.shared.prepareForRefresh()

			let sourceArray = Array(sources)
			let requests = sourceArray.map { (objectID: $0.objectID, url: $0.sourceURL) }
			let sourcesByID = Dictionary(uniqueKeysWithValues: sourceArray.map { ($0.objectID, $0) })
			return (requests, sourcesByID)
		}
		guard let (sourceRequests, sourcesByID) = preparation else { return }

		let refreshJob = JobsManager.shared.start(
			kind: .sourceRefresh,
			title: .localized("Refreshing Sources"),
			detail: .localized("Preparing")
		)

		let effectiveBatchSize = max(batchSize, 1)
		var completedCount = 0
		var successCount = 0
		let dataService = _dataService
		
		for startIndex in stride(from: 0, to: sourceRequests.count, by: effectiveBatchSize) {
			let endIndex = min(startIndex + effectiveBatchSize, sourceRequests.count)
			let batch = sourceRequests[startIndex..<endIndex]
			
			let batchResults = await withTaskGroup(
				of: (NSManagedObjectID, ASRepository?, String?).self,
				returning: [(NSManagedObjectID, ASRepository?, String?)].self
			) { group in
				for request in batch {
					let objectID = request.objectID
					let url = request.url
					group.addTask {
						guard let url else {
							return (objectID, nil, String.localized("Missing source URL"))
						}
						
						return await withCheckedContinuation { continuation in
							dataService.fetch(from: url) { (result: RepositoryDataHandler) in
								switch result {
								case .success(let repo):
									continuation.resume(returning: (objectID, repo, nil))
								case .failure(let error):
									continuation.resume(returning: (objectID, nil, error.localizedDescription))
								}
							}
						}
					}
				}
				
				var results: [(NSManagedObjectID, ASRepository?, String?)] = []
				for await result in group {
					results.append(result)
				}
				return results
			}

			completedCount += batchResults.count
			successCount += batchResults.reduce(into: 0) { count, result in
				if result.1 != nil {
					count += 1
				}
			}
			
			await MainActor.run {
				for (objectID, repo, errorMessage) in batchResults {
					guard let source = sourcesByID[objectID] else { continue }
					if let repo {
						self.sources[source] = repo
						SourceIntelligenceManager.shared.recordSuccess(source: source, repository: repo)
					} else {
						SourceIntelligenceManager.shared.recordFailure(
							source: source,
							message: errorMessage ?? String.localized("Unknown source error")
						)
					}
				}
				JobsManager.shared.update(
					refreshJob,
					progress: sourceRequests.isEmpty ? 1 : Double(completedCount) / Double(sourceRequests.count),
					detail: String.localized("%lld of %lld sources", arguments: completedCount, sourceRequests.count)
				)
			}
		}

		if successCount == 0, !sourceRequests.isEmpty {
			JobsManager.shared.fail(
				refreshJob,
				message: .localized("No sources could be refreshed."),
				detail: .localized("Source refresh failed")
			)
		} else {
			JobsManager.shared.complete(
				refreshJob,
				detail: String.localized("%lld sources refreshed", arguments: successCount)
			)
		}

		await MainActor.run {
			self.isFinished = true
		}
	}
}
