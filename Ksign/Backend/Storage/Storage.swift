//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import Combine
import CoreData

// MARK: - Class
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
	@Published private(set) var persistentStoreError: Error?
	
	private let _name: String = "Feather"
	
	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)
		
		if inMemory {
			container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
		}
		
		container.loadPersistentStores(completionHandler: { (storeDescription, error) in
			if let error {
				DispatchQueue.main.async {
					self.persistentStoreError = error
				}
				print("Unable to load persistent store: \(error.localizedDescription)")
			}
		})
		
		container.viewContext.automaticallyMergesChangesFromParent = true
	}
	
	var context: NSManagedObjectContext {
		container.viewContext
	}

	func dismissPersistentStoreError() {
		persistentStoreError = nil
	}
	
	func saveContext() {
		context.perform {
			guard self.context.hasChanges else { return }
			do {
				try self.context.save()
			} catch {
				print("Unable to save persistent context: \(error.localizedDescription)")
			}
		}
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		guard let untypedRequest = request as? NSFetchRequest<NSFetchRequestResult> else {
			return
		}
		context.performAndWait {
			let deleteRequest = NSBatchDeleteRequest(fetchRequest: untypedRequest)
			do {
				_ = try context.execute(deleteRequest)
				context.reset()
			} catch {
				print("clear: \(error.localizedDescription)")
			}
		}
	}
    
    func countContent<T: NSManagedObject>(for type: T.Type) -> String {
        let request = T.fetchRequest()
		var count = 0
		context.performAndWait {
			count = (try? context.count(for: request)) ?? 0
		}
		return "\(count)"
    }
}
