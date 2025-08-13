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
            .background(Color(uiColor: .quaternarySystemFill))
            .clipShape(Capsule())
    }
}
