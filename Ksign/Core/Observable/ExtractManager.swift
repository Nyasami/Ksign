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
		DispatchQueue.main.async {
			self.extractItems.append(item)
		}
		return item
	}

	func updateProgress(for item: ExtractItem, progress: Double) {
		let clamped = max(0.0, min(1.0, progress))
		DispatchQueue.main.async {
			item.progress = clamped
		}
	}

	func finish(item: ExtractItem) {
		DispatchQueue.main.async {
			if let idx = self.extractItems.firstIndex(where: { $0.id == item.id }) {
				self.extractItems.remove(at: idx)
			}
		}
	}
}


