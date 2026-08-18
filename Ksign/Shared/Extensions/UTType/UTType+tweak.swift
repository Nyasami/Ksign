//
//  UTType+ipa.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import UniformTypeIdentifiers

extension UTType {
	static var dylib: UTType {
		UTType(filenameExtension: "dylib")!
	}
    static var bundle: UTType {
        UTType(filenameExtension: "bundle")!
    }
	static var deb: UTType {
		UTType(filenameExtension: "deb")!
	}
	
	static var framework: UTType {
		UTType(filenameExtension: "framework")!
	}
}
