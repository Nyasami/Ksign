//
//  Storage+Sources.swift
//  Feather
//
//  Created by samara on 12.04.2025.
//

import CoreData
import AltSourceKit

// MARK: - Class extension: Sources
extension Storage {
	/// Retrieve sources in an array, we don't normally need this in swiftUI but we have it for the copy sources action
	func getSources() -> [AltSource] {
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		var sources: [AltSource] = []
		context.performAndWait {
			sources = (try? context.fetch(request)) ?? []
		}
		return sources
	}
	
	func addSource(
		_ url: URL,
		name: String? = "Unknown",
		identifier: String,
		iconURL: URL? = nil,
		deferSave: Bool = false,
		isBuiltIn: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		context.perform {
			do {
				try self._insertSource(
					url,
					name: name,
					identifier: identifier,
					iconURL: iconURL,
					isBuiltIn: isBuiltIn
				)
				if !deferSave {
					try self.context.save()
				}
				completion(nil)
			} catch {
				self.context.rollback()
				completion(error)
			}
		}
	}
	
	func addSource(
		_ url: URL,
		repository: ASRepository,
		id: String = "",
		deferSave: Bool = false,
		isBuiltIn: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		addSource(
			url,
			name: repository.name,
			identifier: !id.isEmpty
						? id
						: (repository.id ?? url.absoluteString),
			iconURL: repository.currentIconURL,
			deferSave: deferSave,
			isBuiltIn: isBuiltIn,
			completion: completion
		)
	}

	func addSources(
		repos: [URL: ASRepository],
		completion: @escaping (Error?) -> Void
	) {
		context.perform {
			do {
				for (url, repo) in repos {
					try self._insertSource(
						url,
						name: repo.name,
						identifier: repo.id ?? url.absoluteString,
						iconURL: repo.currentIconURL,
						isBuiltIn: false
					)
				}
				try self.context.save()
				completion(nil)
			} catch {
				self.context.rollback()
				completion(error)
			}
		}
	}


	func addBuiltInSources(completion: @escaping (Bool) -> Void) {
		let group = DispatchGroup()
		for urlString in _builtInSourceURLs {
			group.enter()
			FR.handleSource(urlString, isBuiltIn: true) { _ in
				group.leave()
			}
		}

		group.notify(queue: .main) {
			let existingURLs = Set(self.getSources().compactMap { $0.sourceURL?.absoluteString })
			completion(self._builtInSourceURLs.allSatisfy(existingURLs.contains))
		}
	}

	func markBuiltInSources() {
		let builtInURLs = Set(_builtInSourceURLs)
		context.perform {
			let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
			do {
				let sources = try self.context.fetch(request)
				var didChange = false
				for source in sources where builtInURLs.contains(source.sourceURL?.absoluteString ?? "") {
					if !source.isBuiltIn {
						source.isBuiltIn = true
						didChange = true
					}
				}
				if didChange {
					try self.context.save()
				}
			} catch {
				print("Unable to mark built-in sources: \(error.localizedDescription)")
			}
		}
	}

	private var _builtInSourceURLs: [String] {
		[
            "https://raw.githubusercontent.com/Nyasami/Ksign/refs/heads/main/repo.json",
            "https://community-apps.sidestore.io/sidecommunity.json",
            "https://xitrix.github.io/iTorrent/AltStore.json",
			"https://repository.apptesters.org",
            "https://github.com/LiveContainer/LiveContainer/releases/download/1.0/apps.json",
			"https://ipa.cypwn.xyz/cypwn.json",
            "https://alt.crystall1ne.dev"
		]
	}

	func deleteSource(for source: AltSource) {
		SourceIntelligenceManager.shared.remove(source)
		context.perform {
			self.context.delete(source)
			do {
				try self.context.save()
			} catch {
				self.context.rollback()
				print("Unable to delete source: \(error.localizedDescription)")
			}
		}
	}

	func sourceExists(_ identifier: String) -> Bool {
		var exists = false
		context.performAndWait {
			exists = self._sourceExists(identifier)
		}
		return exists
	}

	private func _sourceExists(_ identifier: String) -> Bool {
		let fetchRequest: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "identifier == %@", identifier)

		do {
			let count = try context.count(for: fetchRequest)
			return count > 0
		} catch {
			print("Error checking if repository exists: \(error)")
			return false
		}
	}

	private func _insertSource(
		_ url: URL,
		name: String?,
		identifier: String,
		iconURL: URL?,
		isBuiltIn: Bool
	) throws {
		guard !_sourceExists(identifier) else {
			print("ignoring \(identifier)")
			return
		}

		let new = AltSource(context: context)
		new.name = name
		new.date = Date()
		new.identifier = identifier
		new.sourceURL = url
		new.iconURL = iconURL
		new.setValue(isBuiltIn, forKey: "isBuiltIn")
	}
}
