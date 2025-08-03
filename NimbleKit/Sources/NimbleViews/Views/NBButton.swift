//
//  FRButton.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import SwiftUI

public struct NBButton: View {
	private var _title: String
	private var _icon: String
	private var _style: NBToolbarMenuStyle
	private var _horizontalPadding: CGFloat
	
	public init(
		_ title: String,
		systemImage: String,
		style: NBToolbarMenuStyle = .icon,
		horizontalPadding: CGFloat = 12
	) {
		self._title = title
		self._icon = systemImage
		self._style = style
		self._horizontalPadding = horizontalPadding
	}
	
	public var body: some View {
		switch _style {
		case .icon:
			Image(systemName: _icon)
			
		case .text:
			Text(_title)
		}
    }
}
