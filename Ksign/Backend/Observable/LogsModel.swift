//
//  LogsModel.swift
//  Ksign
//
//  Created by Nagata Asami on 8/10/25.
//

import Foundation

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let timestamp: Date

    init(message: String, timestamp: Date = Date()) {
        self.message = message
        self.timestamp = timestamp
    }
}
