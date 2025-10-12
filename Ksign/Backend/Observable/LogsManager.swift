//
//  LogsManager.swift
//  Ksign
//
//  Created by Nagata Asami on 8/10/25.
//

import Foundation
import SwiftUI

final class LogsManager: ObservableObject {
	static let shared = LogsManager()

	@Published var entries: [LogEntry] = []
#if DEBUG
    @Published var isCapturing: Bool = false
#else
    @Published var isCapturing: Bool = true
#endif

	private var _stdoutPipe: Pipe?

	private init() { }

	func startCapture() {
		if _stdoutPipe != nil { return }
		isCapturing = true

		_stdoutPipe = Pipe()

		if let out = _stdoutPipe { _redirect(fd: STDOUT_FILENO, to: out) }

		_setupReadHandler(for: _stdoutPipe)
	}

	func stopCapture() {
		_stdoutPipe?.fileHandleForReading.readabilityHandler = nil

		_stdoutPipe = nil
		isCapturing = false
	}

	func clear() {
		DispatchQueue.main.async { self.entries.removeAll() }
	}

	func exportToText() -> String {
		let exportDateFormatter = DateFormatter()
		exportDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		let exportTimestamp = exportDateFormatter.string(from: Date())

		let timeFormatter = DateFormatter()
		timeFormatter.dateFormat = "HH:mm:ss.SSS"

		// Filter progress logs to reduce spam
		let filteredEntries = filterProgressLogs(entries)

		var logText = "Ksign Logs Export\n"
		logText += "Exported: \(exportTimestamp)\n"
		logText += "Total entries: \(filteredEntries.count) (filtered from \(entries.count) raw entries)\n"
		logText += String(repeating: "=", count: 30) + "\n\n"

		for entry in filteredEntries {
			let time = timeFormatter.string(from: entry.timestamp)
			logText += "[\(time)] \(entry.message)\n"
		}

		return logText
	}

	private func filterProgressLogs(_ entries: [LogEntry]) -> [LogEntry] {
		var filtered: [LogEntry] = []
		var lastProgressPercentage: [String: Int] = [:] // Track last reported percentage per session

		for entry in entries {
			let message = entry.message

			// Check if this is a progress log
			if let progressMatch = message.range(of: #"progress:\s*([\d.]+)"#, options: .regularExpression) {
				let progressString = String(message[progressMatch]).components(separatedBy: ": ")[1]
				if let progressValue = Double(progressString) {
					let percentage = Int(progressValue * 100)

					// Extract session ID if present
					let sessionID = extractSessionID(from: message)

					// Only log at 0%, 25%, 50%, 75%, 100%
					let milestones = [0, 25, 50, 75, 100]
					if milestones.contains(percentage) {
						let key = sessionID ?? "default"
						if lastProgressPercentage[key] != percentage {
							// Format progress message to show percentage
							var filteredMessage = message
							if percentage == 0 {
								filteredMessage = message.replacingOccurrences(
									of: #"progress:\s*[\d.]+"#,
									with: "progress: 0% (started)",
									options: .regularExpression
								)
							} else if percentage == 100 {
								filteredMessage = message.replacingOccurrences(
									of: #"progress:\s*[\d.]+"#,
									with: "progress: 100% (completed)",
									options: .regularExpression
								)
							} else {
								filteredMessage = message.replacingOccurrences(
									of: #"progress:\s*[\d.]+"#,
									with: "progress: \(percentage)%",
									options: .regularExpression
								)
							}
							filtered.append(LogEntry(message: filteredMessage, timestamp: entry.timestamp))
							lastProgressPercentage[key] = percentage
						}
					}
					continue
				}
			}

			// Include all non-progress logs
			filtered.append(entry)
		}

		return filtered
	}

	private func extractSessionID(from message: String) -> String? {
		// Extract UUID pattern like [62BC9551-3A23-452E-9623-AA8224B068E2]
		if let range = message.range(of: #"\[[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\]"#, options: .regularExpression) {
			return String(message[range])
		}
		return nil
	}
	private func _redirect(fd: Int32, to pipe: Pipe) {
		let handle = pipe.fileHandleForWriting
		dup2(handle.fileDescriptor, fd)
	}

	private func _setupReadHandler(for pipe: Pipe?) {
		guard let pipe else { return }
		pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
			guard let self else { return }
			
            let data = handle.availableData
			guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

			let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
			guard !lines.isEmpty else { return }
            
			DispatchQueue.main.async {
				for line in lines { self.entries.append(LogEntry(message: line)) }
			}
		}
	}
}


