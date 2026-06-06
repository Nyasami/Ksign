//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - View
struct AboutView: View {
	@State private var _credits: [CreditsModel] = [
		.init(name: "C", desc: "Developer", github: "claration"),
		.init(name: "Asami", desc: "Developer", github: "Nyasami"),
		.init(name: "Lakhan Lothiyi", desc: "AltStore Repositories", github: "llsc12"),
	]
	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			NBSection(.localized("Credits")) {
				if !_credits.isEmpty {
					ForEach(_credits, id: \.self) { credit in
						_credit(name: credit.name, desc: credit.desc, github: credit.github)
					}
					.transition(.slide)
				}
			}
			
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		FRIconCellView(
			title: name ?? github,
			subtitle: desc ?? "",
			iconUrl: URL(string: "https://github.com/\(github).png"),
			trailing: AnyView(
				Image(systemName: "arrow.up.right")
					.foregroundStyle(.secondary)
			)
		)
		.onTapGesture {
			if let url = URL(string: "https://github.com/\(github)") {
				UIApplication.shared.open(url)
			}
		}
	}
}
