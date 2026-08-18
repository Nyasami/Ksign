//
//  BulkInstallPreviewView.swift
//  Ksign
//
//  Created by Nagata Asami on 27/1/26.
//

import SwiftUI
import NimbleViews

struct BulkInstallPreviewView: View {
    @Environment(\.dismiss) var dismiss
    var apps: [AppInfoPresentable]
    
    let columns = [
        GridItem(.adaptive(minimum: 80))
    ]
    
    var body: some View {
        if apps.count <= 3 {
             HStack(spacing: 20) {
                 ForEach(apps, id: \.uuid) { app in
                     BulkInstallProgressView(app: app)
                         .padding(.horizontal)
                 }
                 
             }
             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
             .background(Color(UIColor.secondarySystemBackground))
             .cornerRadius(22.5)
             .padding()
        } else {
             LazyVGrid(columns: columns, spacing: 20) {
                 ForEach(apps, id: \.uuid) { app in
                     BulkInstallProgressView(app: app)
                 }
             }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(22.5)
            .padding()
        }
    }
}
