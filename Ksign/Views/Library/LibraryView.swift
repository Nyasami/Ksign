//
//  ContentView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	
	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _alertDownloadString: String = "" // for _isDownloadingPresenting
	
	@State private var _searchText = ""
	@State private var _selectedTab: Int = 0 // 0 for Downloaded, 1 for Signed
	
	// MARK: Edit Mode
	@State private var _isEditMode = false
	@State private var _selectedApps: Set<String> = []
	
	@Namespace private var _namespace
	
	// horror
	private func filteredAndSortedApps<T>(from apps: FetchedResults<T>) -> [T] where T: NSManagedObject {
		apps.filter {
			_searchText.isEmpty ||
			(($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}
	
	private var _filteredSignedApps: [Signed] {
		filteredAndSortedApps(from: _signedApps)
	}
	
	private var _filteredImportedApps: [Imported] {
		filteredAndSortedApps(from: _importedApps)
	}
	
	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>
	
	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>
	
	// MARK: Body
    var body: some View {
		NBNavigationView(.localized("Library")) {
			VStack(spacing: 0) {
				Picker("", selection: $_selectedTab) {
					Text(.localized("Downloaded Apps")).tag(0)
					Text(.localized("Signed Apps")).tag(1)
				}
				.pickerStyle(SegmentedPickerStyle())
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				NBListAdaptable {
					if _selectedTab == 0 {
						NBSection(
							.localized("Downloaded Apps"),
							secondary: _filteredImportedApps.count.description
						) {
							ForEach(_filteredImportedApps, id: \.uuid) { app in
								LibraryCellView(
									app: app,
									selectedInfoAppPresenting: $_selectedInfoAppPresenting,
									selectedSigningAppPresenting: $_selectedSigningAppPresenting,
									selectedInstallAppPresenting: $_selectedInstallAppPresenting,
									isEditMode: $_isEditMode,
									selectedApps: $_selectedApps
								)
								.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
							}
						}
					} else {
						NBSection(
							.localized("Signed Apps"),
							secondary: _filteredSignedApps.count.description
						) {
							ForEach(_filteredSignedApps, id: \.uuid) { app in
								LibraryCellView(
									app: app,
									selectedInfoAppPresenting: $_selectedInfoAppPresenting,
									selectedSigningAppPresenting: $_selectedSigningAppPresenting,
									selectedInstallAppPresenting: $_selectedInstallAppPresenting,
									isEditMode: $_isEditMode,
									selectedApps: $_selectedApps
								)
								.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
							}
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .platform())
            .overlay {
                if
                    _filteredSignedApps.isEmpty,
                    _filteredImportedApps.isEmpty
                {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(.localized("No Apps"), systemImage: "questionmark.app.fill")
                        } description: {
                            Text(.localized("Get started by importing your first IPA file."))
                        } actions: {
                            Menu {
                                _importActions()
                            } label: {
                                Text("Import").bg()
                            }
                        }
                    }
                }
            }
			.toolbar {
				if _isEditMode {
					ToolbarItem(placement: .topBarLeading) {
						Button {
							_toggleEditMode()
						} label: {
							NBButton(.localized("Done"), systemImage: "", style: .text)
						}
					}
					
					ToolbarItem(placement: .topBarTrailing) {
						Button {
							_bulkDeleteSelectedApps()
						} label: {
							NBButton(.localized("Delete"), systemImage: "trash", style: .text)
						}
						.disabled(_selectedApps.isEmpty)
					}
				} else {
					ToolbarItem(placement: .topBarLeading) {
						Button {
							_toggleEditMode()
						} label: {
							NBButton(.localized("Edit"), systemImage: "", style: .text)
						}
					}
					
					NBToolbarMenu(
						systemImage: "plus",
						style: .icon,
						placement: .topBarTrailing
					) {
                        _importActions()
                    }
				}
			}
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
					.compatPresentationRadius(21)
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting) { app in
				SigningView(app: app.base, signAndInstall: app.signAndInstall)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }
						
						for ipas in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = downloadManager.startArchive(from: ipas, id: id)
							downloadManager.handlePachageFile(url: ipas, dl: dl) { err in
								if let error = err {
									UIAlertController.showAlertWithOk(title: "Error", message: .localized("Whoops!, something went wrong when extracting the file. \nMaybe try switching the extraction library in the settings?"))
								}
							}
						}
					}
				)
			}
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
				Button(.localized("Cancel"), role: .cancel) {
					_alertDownloadString = ""
				}
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("feather.installApp"))) { notification in
				if let app = notification.object as? AnyApp {
					_selectedInstallAppPresenting = app
				}
			}
        }
    }
}

extension LibraryView {
    @ViewBuilder
    private func _importActions() -> some View {
        Button(.localized("Import from Files"), systemImage: "folder") {
            _isImportingPresenting = true
        }
		.tint(.primary)
        Button(.localized("Import from URL"), systemImage: "globe") {
            _isDownloadingPresenting = true
        }
		.tint(.primary)
    }
}


// MARK: - Extension: View (Edit Mode Functions)
extension LibraryView {
	private func _toggleEditMode() {
		withAnimation(.easeInOut(duration: 0.3)) {
			_isEditMode.toggle()
			if !_isEditMode {
				_selectedApps.removeAll()
			}
		}
	}
	
	private func _bulkDeleteSelectedApps() {
		let appsToDelete = _selectedApps
		
		withAnimation(.easeInOut(duration: 0.5)) {
			for appUUID in appsToDelete {
				if let signedApp = _signedApps.first(where: { $0.uuid == appUUID }) {
					Storage.shared.deleteApp(for: signedApp)
				} else if let importedApp = _importedApps.first(where: { $0.uuid == appUUID }) {
					Storage.shared.deleteApp(for: importedApp)
				}
			}
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
			_selectedApps.removeAll()
			 _toggleEditMode()
		}
	}
}

// MARK: - Extension: View (Import Button Section Header)
extension LibraryView {
	private func sectionHeader(title: String, count: Int) -> some View {
		HStack {
			VStack(alignment: .leading) {
				Text(title)
					.font(.headline)
				Text("\(count)")
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
			
			Spacer()
			
			Button(action: {
				_isImportingPresenting = true
			}) {
				Text(.localized("Import"))
					.font(.subheadline)
					.foregroundColor(.accentColor)
			}
		}
		.padding(.horizontal)
	}
}
