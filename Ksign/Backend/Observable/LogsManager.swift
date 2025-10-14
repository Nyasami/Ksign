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

		var logText = "Ksign Logs Export\n"
		logText += "Exported: \(exportTimestamp)\n"
		logText += "Total entries: \(entries.count)\n"
		logText += String(repeating: "=", count: 30) + "\n\n"

		for entry in entries {
			logText += "\(entry.message)\n"
		}

		return logText
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


