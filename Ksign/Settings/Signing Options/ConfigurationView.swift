//
//  SigningOptionsView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct ConfigurationView: View {
	@StateObject private var _optionsManager = OptionsManager.shared
	@State var isRandomAlertPresenting = false
	@State var randomString = ""
	
	// MARK: Body
    var body: some View {
		NBList(.localized("Signing Options")) {
			NavigationLink(.localized("Display Names"), destination: ConfigurationDictView(
				title: .localized("Display Names"),
					dataDict: $_optionsManager.options.displayNames
				)
			)
			NavigationLink(.localized("Identifers"), destination: ConfigurationDictView(
					title: .localized("Identifers"),
					dataDict: $_optionsManager.options.identifiers
				)
			)
			Section {
				TextField(.localized("Prefix"), text: Binding(
					get: { _optionsManager.options.prefix ?? "" },
					set: { _optionsManager.options.prefix = $0.isEmpty ? nil : $0 }
				))
				TextField(.localized("Suffix"), text: Binding(
					get: { _optionsManager.options.suffix ?? "" },
					set: { _optionsManager.options.suffix = $0.isEmpty ? nil : $0 }
				))
			} footer: {
				Text(.localized("Prefix/Suffix will be added to the app name before and after the app name."))
			}
			
			SigningOptionsView(options: $_optionsManager.options)
		}
		.toolbar {
			NBToolbarMenu(
				systemImage: "character.textbox",
				style: .icon,
				placement: .topBarTrailing
			) {
				_randomMenuItem()
			}
		}
		.alert(_optionsManager.options.ppqString, isPresented: $isRandomAlertPresenting) {
			_randomMenuAlert()
		}
		.onChange(of: _optionsManager.options) { _ in
			_optionsManager.saveOptions()
		}
    }
}

// MARK: - Extension: View
extension ConfigurationView {
	@ViewBuilder
	private func _randomMenuItem() -> some View {
		Section(_optionsManager.options.ppqString) {
			Button(.localized("Change")) {
				isRandomAlertPresenting = true
			}
			Button(.localized("Copy")) {
				UIPasteboard.general.string = _optionsManager.options.ppqString
			}
		}
	}
	
	@ViewBuilder
	private func _randomMenuAlert() -> some View {
		TextField(.localized("String"), text: $randomString)
		Button(.localized("Save")) {
			if !randomString.isEmpty {
				_optionsManager.options.ppqString = randomString
			}
		}
		
		Button(.localized("Cancel"), role: .cancel) {}
	}
}
