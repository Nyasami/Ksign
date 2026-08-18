//
//  Text+bg.swift
//  Ksign
//
//  Created by Nagata Asami on 14/8/25.
//

import SwiftUI

extension Text {
    func bg() -> some View {
        self.padding(.horizontal, 12)
            .frame(height: 29)
            .modifier(style())
            .clipShape(Capsule())
    }
}

struct style: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(Color(uiColor: .quaternarySystemFill))
        }
    }
}
