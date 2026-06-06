import Foundation
import ZIPFoundation

enum ArchivePathError: LocalizedError {
	case unsafePath(String)
	case unsupportedEntry(String)

	var errorDescription: String? {
		switch self {
		case .unsafePath(let path):
			return "Archive contains an unsafe path: \(path)"
		case .unsupportedEntry(let path):
			return "Archive contains an unsupported link entry: \(path)"
		}
	}
}

enum ArchivePathValidator {
	static func destinationURL(base: URL, entryPath: String) throws -> URL {
		let normalizedPath = entryPath.replacingOccurrences(of: "\\", with: "/")
		guard
			!normalizedPath.isEmpty,
			!normalizedPath.hasPrefix("/"),
			!normalizedPath.contains("\0")
		else {
			throw ArchivePathError.unsafePath(entryPath)
		}

		let resolvedBase = base.standardizedFileURL.resolvingSymlinksInPath()
		let destination = base
			.appendingPathComponent(normalizedPath)
			.standardizedFileURL
			.resolvingSymlinksInPath()
		let basePath = resolvedBase.path.hasSuffix("/") ? resolvedBase.path : resolvedBase.path + "/"

		guard destination.path == resolvedBase.path || destination.path.hasPrefix(basePath) else {
			throw ArchivePathError.unsafePath(entryPath)
		}
		return destination
	}

	static func validateZipArchive(at archiveURL: URL, destination: URL) throws {
		let archive = try Archive(url: archiveURL, accessMode: .read)
		for entry in archive {
			_ = try destinationURL(base: destination, entryPath: entry.path)
			if entry.type == .symlink {
				throw ArchivePathError.unsupportedEntry(entry.path)
			}
		}
	}
}
