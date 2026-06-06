//
//  ExtractManager.swift
//  Ksign
//
//  Created by Nagata Asami on 3/10/25.
//

import Foundation
import Combine

final class ExtractItem: ObservableObject, Identifiable {
	@Published var progress: Double = 0.0
	let id: String
	let fileName: String
	var jobID: String { "extract.\(id)" }

	init(id: String = UUID().uuidString, fileName: String) {
		self.id = id
		self.fileName = fileName
	}
}

final class ExtractManager: ObservableObject {
	static let shared = ExtractManager()

	@Published var extractItems: [ExtractItem] = []

	private init() { }

	@discardableResult
	func start(fileName: String) -> ExtractItem {
		let item = ExtractItem(fileName: fileName)
		JobsManager.shared.start(
			kind: .extraction,
			title: fileName,
			detail: .localized("Extracting"),
			id: item.jobID
		)
		DispatchQueue.main.async {
			self.extractItems.append(item)
		}
		return item
	}

	func updateProgress(for item: ExtractItem, progress: Double) {
		let clamped = max(0.0, min(1.0, progress))
		DispatchQueue.main.async {
			item.progress = clamped
			JobsManager.shared.update(item.jobID, progress: clamped, detail: .localized("Extracting"))
		}
	}

	func finish(item: ExtractItem, error: Error? = nil) {
		DispatchQueue.main.async {
			if let idx = self.extractItems.firstIndex(where: { $0.id == item.id }) {
				self.extractItems.remove(at: idx)
			}
			if let error {
				JobsManager.shared.fail(item.jobID, error: error, detail: .localized("Extraction failed"))
			} else {
				JobsManager.shared.complete(item.jobID, detail: .localized("Extraction completed"))
			}
		}
	}
}


