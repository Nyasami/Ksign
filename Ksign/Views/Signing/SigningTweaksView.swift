//
//  SigningTweaksView.swift
//  Feather
//
//  Created by samara on 20.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SigningTweaksView: View {
	@State private var _isAddingPresenting = false
	@State private var _tweaksInDirectory: [URL] = []
	@State private var _enabledTweaks: Set<URL> = []
	
	@Binding var options: Options
	
	// MARK: Body
	var body: some View {
		List {
			if !options.injectionFiles.isEmpty {
				Section(header: Text("Added Tweaks").font(.subheadline)) {
					ForEach(options.injectionFiles, id: \.absoluteString) { tweak in
						_file(tweak: tweak, isFromOptions: true)
					}
				}
			}
			if !_tweaksInDirectory.isEmpty {
				Section(header: Text("Available Tweaks").font(.subheadline)) {
					ForEach(_tweaksInDirectory, id: \.absoluteString) { tweak in
						_file(tweak: tweak, isFromOptions: false)
					}
				}
			}
		}
		.overlay(alignment: .center) {
			if options.injectionFiles.isEmpty && _tweaksInDirectory.isEmpty {
				if #available(iOS 17, *) {
					ContentUnavailableView {
						Label(.localized("No Tweaks"), systemImage: "gear.badge.questionmark")
					} description: {
						Text(.localized("Get started by importing your first tweak."))
					} actions: {
						Button {
							_isAddingPresenting = true
						} label: {
							Text("Import").bg()
						}
					}
				} else {
					Text("No tweaks found. Add tweaks using the + button.")
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity, alignment: .center)
						.padding()
				}
			}
		}
		.navigationTitle(.localized("Tweaks"))
		.listStyle(.plain)
		.toolbar {
			NBToolbarButton(
				systemImage: "plus",
				style: .icon,
				placement: .topBarTrailing
			) {
				_isAddingPresenting = true
			}
		}
		.sheet(isPresented: $_isAddingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.item],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					_importTweaks(urls: urls)
				}
			)
		}
		.animation(.smooth, value: options.injectionFiles)
		.animation(.smooth, value: _tweaksInDirectory)
		.onAppear(perform: _loadTweaks)
	}
	
	private func _loadTweaks() {
		let tweaksDir = FileManager.default.tweaks
		guard let files = try? FileManager.default.contentsOfDirectory(
			at: tweaksDir,
			includingPropertiesForKeys: nil
		) else { return }
		
		_tweaksInDirectory = files.filter { url in
			let ext = url.pathExtension.lowercased()
			return ext == "dylib" || ext == "deb" || ext == "framework"
		}
		
		_enabledTweaks = Set(options.injectionFiles)
	}
	
    private func _importTweaks(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let tweaksDir = FileManager.default.tweaks
        
        do {
            try FileManager.default.createDirectoryIfNeeded(at: tweaksDir)
        } catch {
            print("Error creating tweaks directory: \(error)")
            return
        }
        
        let allowedExtensions = Set(["dylib", "deb", "framework"])   
        
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }
            
            let destinationURL = tweaksDir.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                if !options.injectionFiles.contains(destinationURL) {
                    options.injectionFiles.append(destinationURL)
                }
            } catch {
                print("Error copying tweak file: \(error)")
            }
        }
        
        _loadTweaks()
    }
}

// MARK: - Extension: View
extension SigningTweaksView {
	@ViewBuilder
	private func _file(tweak: URL, isFromOptions: Bool) -> some View {
		HStack {
			Text(tweak.lastPathComponent)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)
			
			if !isFromOptions {
				Toggle("", isOn: Binding(
					get: { _enabledTweaks.contains(tweak) },
					set: { newValue in
						if newValue {
							_enabledTweaks.insert(tweak)
							if !options.injectionFiles.contains(tweak) {
								options.injectionFiles.append(tweak)
							}
						} else {
							_enabledTweaks.remove(tweak)
							if let index = options.injectionFiles.firstIndex(of: tweak) {
								options.injectionFiles.remove(at: index)
							}
						}
					}
				))
				.labelsHidden()
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			Button(role: .destructive) {
				if isFromOptions {
					FileManager.default.deleteStored(tweak) { url in
						if let index = options.injectionFiles.firstIndex(where: { $0 == url }) {
							options.injectionFiles.remove(at: index)
						}
						_loadTweaks()
					}
				} else {
					do {
						try FileManager.default.removeItem(at: tweak)
						if let index = options.injectionFiles.firstIndex(of: tweak) {
							options.injectionFiles.remove(at: index)
						}
						_enabledTweaks.remove(tweak)
						_loadTweaks()
					} catch {
						print("Error deleting tweak: \(error)")
					}
				}
			} label: {
				Label(.localized("Delete"), systemImage: "trash")
			}
		}
	}
}
