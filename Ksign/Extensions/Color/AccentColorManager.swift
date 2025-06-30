//
//  AccentColorManager.swift
//  Ksign
//
//  Created by Nagata Asami on 6/30/25.
//

import SwiftUI
import UIKit

// MARK: - Accent Color Manager
class AccentColorManager: ObservableObject {
    static let shared = AccentColorManager()
    
    @AppStorage("Feather.accentColor") private var _selectedAccentColor: Int = 0 {
        didSet {
            objectWillChange.send()
        }
    }
    
    private let _accentColors: [(color: Color, uiColor: UIColor)] = [
        (Color(red: 0x53/255, green: 0x94/255, blue: 0xF7/255), UIColor(red: 0x53/255, green: 0x94/255, blue: 0xF7/255, alpha: 1.0)), // Default
        (Color(red: 0xFF/255, green: 0x8B/255, blue: 0x92/255), UIColor(red: 0xFF/255, green: 0x8B/255, blue: 0x92/255, alpha: 1.0)), //rgb(255, 139, 146)
        (.red, .systemRed),
        (.orange, .systemOrange),
        (.yellow, .systemYellow),
        (.green, .systemGreen),
        (.blue, .systemBlue),
        (.purple, .systemPurple),
        (.pink, .systemPink),
        (.indigo, .systemIndigo),
        (.mint, .systemMint),
        (.cyan, .systemCyan),
        (.teal, .systemTeal)
    ]
    
    var currentAccentColor: Color {
        guard _selectedAccentColor < _accentColors.count else {
            return _accentColors[0].color
        }
        return _accentColors[_selectedAccentColor].color
    }
    
    var currentUIColor: UIColor {
        guard _selectedAccentColor < _accentColors.count else {
            return _accentColors[0].uiColor
        }
        return _accentColors[_selectedAccentColor].uiColor
    }
    
    /// Updates the global app tint color
    func updateGlobalTintColor() {
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { window in
                    window.tintColor = self.currentUIColor
                }
        }
    }
} 