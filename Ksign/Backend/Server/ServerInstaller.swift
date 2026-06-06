//
//  Server.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import Vapor
import NIOSSL
import NIOTLS
import SwiftUI
import IDeviceSwift

// MARK: - Class
class ServerInstaller: Identifiable, ObservableObject {
	let id = UUID()
	let port = Int.random(in: 4000...8000)
	let requiresServer: Bool
	private var _needsShutdown = false
	
	var packageUrl: URL?
	let appIdentifier: String?
	let appName: String?
	let appVersion: String?
	@ObservedObject var viewModel: InstallerStatusViewModel
	private var _server: Application?
	private(set) var startupError: Error?

	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel, requiresServer: Bool = true) {
		self.appIdentifier = app.identifier
		self.appName = app.name
		self.appVersion = app.version
		self.viewModel = viewModel
		self.requiresServer = requiresServer
		self._server = nil
		self.startupError = nil

		guard requiresServer else { return }

		do {
			let server = try Self.setupApp(port: port)
			self._server = server
			try _configureRoutes()
			try server.server.start()
			_needsShutdown = true
		} catch {
			self._server?.shutdown()
			self._server = nil
			self.startupError = error
			DispatchQueue.main.async {
				viewModel.status = .broken(error)
			}
		}
	}
	
	deinit {
		_shutdownServer()
	}
		
	private func _configureRoutes() throws {
		guard let server = _server else {
			throw ServerInstallerError.unavailable
		}
		server.get("*") { [weak self] req in
			guard let self else { return Response(status: .badGateway) }
			switch req.url.path {
			case plistEndpoint.path:
				self._updateStatus(.sendingManifest)
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "text/xml",
				], body: .init(data: installManifestData))
			case displayImageSmallEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageSmallData))
			case displayImageLargeEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageLargeData))
			case payloadEndpoint.path:
				guard let packageUrl = packageUrl else {
					return Response(status: .notFound)
				}
				
				self._updateStatus(.sendingPayload)
				
				return req.fileio.streamFile(
					at: packageUrl.path
				) { result in
                    switch result {
                    case .success:
                        self._updateStatus(.installing)
                    case .failure(let error):
                        self._updateStatus(.broken(error))
                    }
				}
			case "/install":
				var headers = HTTPHeaders()
				headers.add(name: .contentType, value: "text/html")
				return Response(status: .ok, headers: headers, body: .init(string: self.html))
			default:
				return Response(status: .notFound)
			}
		}
	}
	
	private func _shutdownServer() {
		guard _needsShutdown, let server = _server else { return }
		
		_needsShutdown = false
		server.server.shutdown()
		server.shutdown()
	}
	
    private func _updateStatus(_ newStatus: InstallerStatusViewModel.InstallerStatus) {
		DispatchQueue.main.async {
			self.viewModel.status = newStatus
		}
	}
		
	static func getServerMethod() -> Int {
		UserDefaults.standard.integer(forKey: "Feather.serverMethod")
	}
	
	static func getIPFix() -> Bool {
		UserDefaults.standard.bool(forKey: "Feather.ipFix")
	}
	
	static func setServerMethod(_ method: Int) {
		UserDefaults.standard.set(method, forKey: "Feather.serverMethod")
	}
	
	static func setIPFix(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: "Feather.ipFix")
	}
}

enum ServerInstallerError: LocalizedError {
	case unavailable
	case missingTLSCredentials

	var errorDescription: String? {
		switch self {
		case .unavailable:
			return "Unable to start the local installation server."
		case .missingTLSCredentials:
			return "The local installation server is missing its TLS certificate or private key."
		}
	}
}
