//
//  Date+stripTime.swift
//  Feather
//
//  Created by samara on 21.06.2025.
//

import Foundation.NSDate

extension Date {
    func stripTime() -> Date {
        Calendar.current.startOfDay(for: self)
    }
}
