//
//  UTType+ipa.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import UniformTypeIdentifiers

extension UTType {
	static var dylib: UTType {
		UTType(filenameExtension: "dylib") ?? .data
	}
    static var bundle: UTType {
        UTType(filenameExtension: "bundle") ?? .folder
    }
	static var deb: UTType {
		UTType(filenameExtension: "deb") ?? .data
	}
	
	static var framework: UTType {
		UTType(filenameExtension: "framework") ?? .folder
	}
}
