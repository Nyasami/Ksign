//
//  Server+Compute.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import UIKit.UIGraphicsImageRenderer

extension ServerInstaller {
	var plistEndpoint: URL {
		_endpoint(path: "/\(id).plist")
	}

	var payloadEndpoint: URL {
		_endpoint(path: "/\(id).ipa")
	}
	
	var pageEndpoint: URL {
		_endpoint(path: "/install")
	}
	
	var externalServerLink: String {
		let bundleID = appIdentifier ?? "unknown"
		let name = appName ?? "Unknown"
		let version = appVersion ?? "0"
		let baseUrl = "https://api.palera.in/genPlist?bundleid=\(bundleID)&name=\(name)&version=\(version)&fetchurl=\(self.payloadEndpoint.absoluteString)"
		let encodedBaseUrl = baseUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? baseUrl
		let finalEncodedUrl = encodedBaseUrl.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? encodedBaseUrl
		
		return finalEncodedUrl
	}

	var iTunesLink: String {
		_iTunesLink(with: plistEndpoint.absoluteString)
	}
	
	var iTunesLinkExternal: String {
		_iTunesLink(with: externalServerLink)
	}
	
	private func _iTunesLink(with url: String) -> String {
		return "itms-services://?action=download-manifest&url=\(url)"
	}

	var displayImageSmallEndpoint: URL {
		_endpoint(path: "/app57x57.png", scheme: "https")
	}

	var displayImageLargeEndpoint: URL {
		_endpoint(path: "/app512x512.png", scheme: "https")
	}

	private func _endpoint(path: String, scheme: String? = nil) -> URL {
		var comps = URLComponents()
		comps.scheme = scheme ?? (ServerInstaller.getServerMethod() == 1 ? "http" : "https")
		comps.host = Self.sni
		comps.path = path
		comps.port = port
		return comps.url ?? URL(fileURLWithPath: path)
	}
	
	var displayImageSmallData: Data {
		_createIcon(57)
	}
	
	var displayImageLargeData: Data {
		_createIcon(512)
	}
	
	private func _createIcon(_ r: CGFloat) -> Data {
		let renderer = UIGraphicsImageRenderer(size: .init(width: r, height: r))
		let image = renderer.image { ctx in
			UIColor.accent.setFill()
			ctx.fill(.init(x: 0, y: 0, width: r, height: r))
		}
		return image.pngData() ?? Data()
	}

	var html: String {
		"""
		<html style="background-color: black;">
		<script type="text/javascript">window.location="\(iTunesLinkExternal)"</script>
		</html>
		"""
	}

	var installManifest: [String: Any] {[
		"items": [[
			"assets": [
				[
					"kind": "software-package",
					"url": payloadEndpoint.absoluteString,
				],
				[
					"kind": "display-image",
					"url": "https://raw.githubusercontent.com/Nyasami/Ksign/refs/heads/main/Ksign/Resources/Assets.xcassets/AppIcons/AppIcon.appiconset/Ksign-default.png",
				],
			],
			"metadata": [
				"bundle-identifier": appIdentifier ?? "unknown",
				"bundle-version": appVersion ?? "0",
				"kind": "software",
				"title": appName ?? "Unknown",
			],
		],],
	]}

	var installManifestData: Data {
		(try? PropertyListSerialization.data(
			fromPropertyList: installManifest,
			format: .xml,
			options: .zero
		)) ?? .init()
	}
}
