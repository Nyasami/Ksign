//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct SettingsView: View {
	private let _donationsUrl = "https://github.com/sponsors/nyasami"
	private let _githubUrl = "https://github.com/nyasami/ksign"
    private let _discordUrl = "https://discord.gg/sfbZfQzVdQ"
	// MARK: Body
    var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
//				#if !NIGHTLY && !DEBUG
				SettingsDonationCellView(site: _donationsUrl)
//				#endif
				
				_feedback()
				
				Section {
                    NavigationLink(destination: AppIconView()) {
                        Label(.localized("App Icon"), systemImage: "app.badge")
                    }
					NavigationLink(destination: AppearanceView()) {
                        Label(.localized("Appearance"), systemImage: "paintbrush")
                    }
				}
				
				NBSection(.localized("Features")) {
					NavigationLink(destination: CertificatesView()) {
                        Label(.localized("Certificates"), systemImage: "signature")
                    }
					NavigationLink(destination: ConfigurationView()) {
                        Label(.localized("Signing Options"), systemImage: "gear")
                    }
					NavigationLink(destination: ArchiveView()) {
                        Label(.localized("Archive & Extraction"), systemImage: "archivebox")
                    }
					#if SERVER
					NavigationLink(destination: ServerView()) {
                        Label(.localized("Server & SSL"), systemImage: "server.rack")
                    }
					#elseif IDEVICE
					NavigationLink(destination: TunnelView()) {
                        Label(.localized("Tunnel & Pairing"), systemImage: "network")
                    }
					#endif
				}
				
				_directories()
            }
        }
    }
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(destination: AboutNyaView()) {
                Label(.localized("About"), systemImage: "info.circle")
            }
			Button(.localized("Telegram Channel"), systemImage: "paperplane.circle") {
				UIApplication.open("https://t.me/KhoinDNS")
			}
			Button(.localized("GitHub Repository"), systemImage: "safari") {
				UIApplication.open(_githubUrl)
			}
            Button(.localized("Discord Server"), systemImage: "safari") {
                UIApplication.open(_discordUrl)
            }
		}
	}
	
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of Ksign files except certificates are contained in the documents directory, here are some quick links to these."))
		}
	}
}
