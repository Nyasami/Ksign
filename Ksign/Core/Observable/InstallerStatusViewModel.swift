//
//  StatusViewModel.swift
//  Feather
//
//  Created by samara on 24.04.2025.
//

import Foundation
import Combine
import IDeviceSwift

extension InstallerStatusViewModel {
	
	var statusImage: String {
		switch status {
		case .none: return "archivebox.fill"
		case .ready: return "app.gift"
		case .sendingManifest, .sendingPayload: return "paperplane.fill"
		case .installing: return "square.and.arrow.down"
		case .completed: return "app.badge.checkmark"
		case .broken: return "exclamationmark.triangle.fill"
		}
	}
	
	var statusLabel: String {
		switch status {
		case .none: return "Packaging"
		case .ready: return "Ready"
		case .sendingManifest: return "Sending Manifest"
		case .sendingPayload: return "Sending Payload"
		case .installing: return "Installing"
		case .completed: return "Completed"
		case .broken: return "Error"
		}
	}
}
