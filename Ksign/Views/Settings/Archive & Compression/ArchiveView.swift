//
//  ArchiveView.swift
//  Feather
//
//  Created by samara on 6.05.2025.
//

import SwiftUI
import Zip
import NimbleViews

struct ArchiveView: View {
	@AppStorage("Feather.compressionLevel") private var _compressionLevel: Int = ZipCompression.DefaultCompression.rawValue
	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = true
	@AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false
	@AppStorage("Feather.extractionLibrary") private var _extractionLibrary: String = "Zip"
    
    var body: some View {
		NBList(.localized("Archive & Compression")) {
			Section {
				Picker(.localized("Compression Level"), systemImage: "archivebox", selection: $_compressionLevel) {
					ForEach(ZipCompression.allCases, id: \.rawValue) { level in
						Text(level.label).tag(level)
					}
				}
			}
			
			Section {
				Toggle(.localized("Show Sheet when Exporting"), systemImage: "square.and.arrow.up", isOn: $_useShareSheet)
			} footer: {
				Text(.localized("Toggling show sheet will present a share sheet after exporting to your files."))
			}
            
            Section {
                Toggle(.localized("Use last copied location"), systemImage: "clock.arrow.circlepath", isOn: $_useLastExportLocation)
            } footer: {
                Text(.localized("Whether to remember the last location where a file was copied/moved to or use Ksign's documents folder as default."))
            }

            Section {
                Picker(.localized("Extraction Library"), systemImage: "archivebox.circle.fill", selection: $_extractionLibrary) {
                    ForEach(Options.extractionLibraryValues, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
            } footer: {
                Text(.localized("Choose which library to use for extracting archives. ZIPFoundation is recommended for large files or when Zip is not working."))
            }
		}
    }
}
