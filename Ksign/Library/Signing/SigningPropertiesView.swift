//
//  SigningAppPropertiesView.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningPropertiesView: View {
	@Environment(\.dismiss) var dismiss
	
	@State private var text: String = ""
	
	var saveButtonDisabled: Bool {
		text == initialValue
	}
	
	var title: String
	var initialValue: String 
	var certAppId: String? = nil
	@Binding var bindingValue: String?
	
	// MARK: Body
	var body: some View {
        NBList(title) {
            TextField(initialValue, text: $text)
                .textInputAutocapitalization(.none)
            if certAppId != nil {
                Section {
                    Button {
                        text = certAppId ?? ""
                    } label: {
                        Text(.localized("Matching Certificate's App ID"))
                    }
                    .disabled(certAppId == nil)
                } footer: {
                    Text(.localized("Use certiticate's app ID, this will help the app have access to features that uses certificate's entitlements."))
                }
            }
        }
		.toolbar {
			NBToolbarButton(
				.localized("Save"),
				style: .text,
				placement: .topBarTrailing,
				isDisabled: saveButtonDisabled
			) {
				if !saveButtonDisabled {
					bindingValue = text
					dismiss()
				}
			}
		}
		.onAppear {
			text = initialValue
		}
	}
}
