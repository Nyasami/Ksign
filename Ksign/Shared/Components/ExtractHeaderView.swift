//
//  ExtractHeaderView.swift
//  Ksign
//
//  Created by Nagata Asami on 3/10/25.
//

import SwiftUI

struct ExtractHeaderView: View {
	@ObservedObject var extractManager: ExtractManager

	var body: some View {
		ZStack {
			if !extractManager.extractItems.isEmpty,
				let first = extractManager.extractItems.first
			{
				VStack {
					VStack(spacing: 12) {
						ExtractProgressItemView(item: first)
						if extractManager.extractItems.count > 1 {
							HStack {
								Spacer()
								Text(verbatim: "+\(extractManager.extractItems.count - 1)")
									.font(.caption)
									.foregroundColor(.secondary)
									.padding(.vertical, 4)
							}
						}
					}
					.padding(.horizontal)
				}
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(.spring(), value: extractManager.extractItems.count)
	}
}

private struct ExtractProgressItemView: View {
	@ObservedObject var item: ExtractItem

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(item.fileName)
				.font(.subheadline)
				.lineLimit(1)

			ProgressView(value: item.progress)
				.progressViewStyle(.linear)

			HStack {
				Text(verbatim: "\(Int(item.progress * 100))%")
					.contentTransition(.numericText())
				Spacer()
			}
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.padding(.vertical, 4)
	}
}

