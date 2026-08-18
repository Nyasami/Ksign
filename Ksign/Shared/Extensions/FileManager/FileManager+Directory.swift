import Foundation

extension FileManager {
    func volumeAvailableCapacity(for url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        guard let capacity = resourceValues.volumeAvailableCapacity else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: nil)
        }
        return Int64(capacity)
    }
} 
