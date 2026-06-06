//
//  Server+TLS.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import NIOSSL
import NIOTLS
import Vapor
import SystemConfiguration.CaptiveNetwork

// MARK: - Class extension: TLS/Setup
extension ServerInstaller {
	// MARK: Setup
	private static let environmentResult: Result<Environment, Error> = Result {
		var environment = try Environment.detect()
		try LoggingSystem.bootstrap(from: &environment)
		return environment
	}
	
	static func setupApp(port: Int) throws -> Application {
		let app = Application(try environmentResult.get())
		do {
			app.threadPool = .init(numberOfThreads: 1)

			if ServerInstaller.getServerMethod() != 1 {
				guard let tls = try Self.tls() else {
					throw ServerInstallerError.missingTLSCredentials
				}
				app.http.server.configuration.tlsConfiguration = tls
			}

			app.http.server.configuration.hostname = Self.sni
			app.http.server.configuration.tcpNoDelay = true
			app.http.server.configuration.address = .hostname("0.0.0.0", port: port)
			app.http.server.configuration.port = port
			app.routes.defaultMaxBodySize = "128mb"
			app.routes.caseInsensitive = false

			return app
		} catch {
			app.shutdown()
			throw error
		}
	}
	
	// MARK: Files/IP
	static let sni: String = {
		let localhost = "127.0.0.1"
		
		if getServerMethod() == 1 {
			return !ServerInstaller.getIPFix()
			? (getLocalAddress() ?? localhost)
			: localhost
		} else {
			return readCommonName() ?? localhost
		}
	}()
	
	static func tls() throws -> TLSConfiguration? {
		guard
			let crt = getUrl("server", ext: "crt"),
			let pem = getUrl("server", ext: "pem")
		else {
			return nil
		}
		
		return try TLSConfiguration.makeServerConfiguration(
			certificateChain: NIOSSLCertificate.fromPEMFile(crt.path).map {
				NIOSSLCertificateSource.certificate($0)
			},
			privateKey: .privateKey(
				try NIOSSLPrivateKey(file: pem.path, format: .pem)
			)
		)
	}
	
	static func readCommonName() -> String? {
		guard let url = getUrl("commonName", ext: "txt") else {
			return nil
		}
		
		return try? String(contentsOf: url, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

extension ServerInstaller {
	static func getUrl(_ name: String, ext: String) -> URL? {
		let fileManager = FileManager.default
		
		let serverURL = URL.documentsDirectory.appendingPathComponent("App").appendingPathComponent("Server").appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: serverURL.path) {
			return serverURL
		}
		
		let documentsURL = URL.documentsDirectory.appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: documentsURL.path) {
			return documentsURL
		}
		
		let oldServerURL = URL.documentsDirectory.appendingPathComponent("Server").appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: oldServerURL.path) {
			return oldServerURL
		}
		
		return Bundle.main.url(forResource: name, withExtension: ext)
	}
	
	static func getLocalAddress() -> String? {
		var address: String?
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		
		if getifaddrs(&ifaddr) == 0 {
			var ptr = ifaddr
			while let pointer = ptr {
				let interface = pointer.pointee
				guard let interfaceAddress = interface.ifa_addr else {
					ptr = interface.ifa_next
					continue
				}
				let addrFamily = interfaceAddress.pointee.sa_family
				
				if addrFamily == UInt8(AF_INET) {
					
					let name = String(cString: interface.ifa_name)
					if name == "en0" || name == "pdp_ip0" {
						
						var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
						if getnameinfo(interfaceAddress, socklen_t(interfaceAddress.pointee.sa_len),
									   &hostname, socklen_t(hostname.count),
									   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
							address = String(cString: hostname)
						}
						
					}
				}
				ptr = interface.ifa_next
			}
			freeifaddrs(ifaddr)
		}
		
		return address
	}
}
