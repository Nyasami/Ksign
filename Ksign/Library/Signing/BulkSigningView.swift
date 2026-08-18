//
//  BulkSigningView.swift
//  Ksign
//
//  Created by Nagata Asami on 11/9/25.
//

import SwiftUI
import NimbleViews
import PhotosUI

struct AppSignConfig: Identifiable {
    var id: String? { app.uuid }
    var app: AppInfoPresentable
    var options: Options
    var icon: UIImage?
}

struct BulkSigningView: View {
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	@StateObject private var _optionsManager = OptionsManager.shared
	@State private var _configs: [AppSignConfig]
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State private var _editingConfigId: String?
	
	@Environment(\.dismiss) private var dismiss
	var apps: [AppInfoPresentable]

	init(apps: [AppInfoPresentable]) {
		self.apps = apps
		let storedCert = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
		
		let defaultOptions = OptionsManager.shared.options
		__configs = State(initialValue: apps.map { AppSignConfig(app: $0, options: defaultOptions, icon: nil) })
	}

	var body: some View {
		NBNavigationView(.localized("Bulk Signing"), displayMode: .inline) {
			Form {
                _cert()
				
				ForEach($_configs) { $config in
					Section {
						_customizationOptions(for: $config)
						_customizationProperties(for: $config)
					}
				}
			}
			.safeAreaInset(edge: .bottom) {
				Button {
					_start()
				} label: {
					NBSheetButton(title: .localized("Start Signing"))
				}
			}
			.toolbar {
				NBToolbarButton(role: .dismiss)
				
				NBToolbarButton(
					.localized("Reset"),
					style: .text,
					placement: .topBarTrailing
				) {
					let defaultOptions = OptionsManager.shared.options
					for i in _configs.indices {
						_configs[i].options = defaultOptions
						_configs[i].icon = nil
					}
				}
			}
			.sheet(isPresented: $_isAltPickerPresenting) {
				if let id = _editingConfigId, let index = _configs.firstIndex(where: { $0.id == id }) {
					let appBase = _configs[index].app
					let iconBinding = Binding<UIImage?>(
						get: { _configs[index].icon },
						set: { _configs[index].icon = $0 }
					)
					SigningAlternativeIconView(app: appBase, appIcon: iconBinding, isModifing: .constant(true))
				}
			}
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						guard let id = _editingConfigId, let index = _configs.firstIndex(where: { $0.id == id }) else { return }
						_configs[index].icon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task { @MainActor in
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						if let id = _editingConfigId, let index = _configs.firstIndex(where: { $0.id == id }) {
							_configs[index].icon = image
						}
					}
				}
			}
			.disabled(_isSigning)
			.animation(.smooth, value: _isSigning)
		}
	}
}

extension BulkSigningView {
	@ViewBuilder
	private func _customizationOptions(for config: Binding<AppSignConfig>) -> some View {
			Menu {
				Button(.localized("Select Alternative Icon")) {
					_editingConfigId = config.wrappedValue.id
					_isAltPickerPresenting = true 
				}
				Button(.localized("Choose from Files")) {
					_editingConfigId = config.wrappedValue.id
					_isFilePickerPresenting = true 
				}
				Button(.localized("Choose from Photos")) {
					_editingConfigId = config.wrappedValue.id
					_isImagePickerPresenting = true 
				}
			} label: {
				if let customIcon = config.icon.wrappedValue {
					Image(uiImage: customIcon)
						.resizable()
						.frame(width: 55, height: 55)
						.cornerRadius(12)
				} else {
					FRAppIconView(app: config.app.wrappedValue, size: 55)
				}
			}
			_infoCell(.localized("Name"), desc: config.options.appName.wrappedValue ?? config.app.wrappedValue.name) {
				SigningPropertiesView(
					title: .localized("Name"),
					initialValue: config.options.appName.wrappedValue ?? (config.app.wrappedValue.name ?? ""),
					bindingValue: config.options.appName
				)
			}
			_infoCell(.localized("Identifier"), desc: config.options.appIdentifier.wrappedValue ?? config.app.wrappedValue.identifier) {
				SigningPropertiesView(
					title: .localized("Identifier"),
					initialValue: config.options.appIdentifier.wrappedValue ?? (config.app.wrappedValue.identifier ?? ""),
					bindingValue: config.options.appIdentifier
				)
			}
			_infoCell(.localized("Version"), desc: config.options.appVersion.wrappedValue ?? config.app.wrappedValue.version) {
				SigningPropertiesView(
					title: .localized("Version"),
					initialValue: config.options.appVersion.wrappedValue ?? (config.app.wrappedValue.version ?? ""),
					bindingValue: config.options.appVersion
				)
			}
	}
	

	@ViewBuilder
	private func _cert() -> some View {
		NBSection(.localized("Signing")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for config: Binding<AppSignConfig>) -> some View {
			DisclosureGroup(.localized("Modify")) {
				NavigationLink(.localized("Existing Dylibs")) {
					SigningDylibView(
						app: config.app.wrappedValue,
						options: config.options.optional()
					)
				}
				
				NavigationLink(String.localized("Frameworks & PlugIns")) {
					SigningFrameworksView(
						app: config.app.wrappedValue,
						options: config.options.optional()
					)
				}
				#if NIGHTLY || DEBUG
				NavigationLink(String.localized("Entitlements")) {
					SigningEntitlementsView(
						bindingValue: config.options.appEntitlementsFile
					)
				}
				#endif
				NavigationLink(String.localized("Tweaks")) {
					SigningTweaksView(
						options: config.options
					)
				}
			}
			
			NavigationLink(String.localized("Properties")) {
				Form { SigningOptionsView(
					options: config.options,
					temporaryOptions: _optionsManager.options
				)}
			.navigationTitle(.localized("Properties"))
		}
	}

	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? .localized("Unknown"))
			}
		}
	}

	private func _start() {
		let canSign = _selectedCert() != nil || _configs.allSatisfy { $0.options.doAdhocSigning || $0.options.onlyModify }
		guard canSign else {
			UIAlertController.showAlertWithOk(
				title: .localized("No Certificate"),
				message: .localized("Please go to settings and import a valid certificate"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
		_isSigning = true

		
		for config in _configs {
			FR.signPackageFile(
				config.app,
				using: config.options,
				icon: config.icon,
				certificate: _selectedCert()
			) { [self] error in
				if let error {
					UIAlertController.showAlertWithOk(title: "Error", message: error.localizedDescription)
				}
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
					NotificationCenter.default.post(name: NSNotification.Name("ksign.bulkSigningFinished"), object: nil)
				}
				dismiss()
			}
		}

	}
}
