//
//  CertificatesAddView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	
	@State private var _p12Data: Data? = nil
	@State private var _provisionData: Data? = nil
	@State private var _isFromKsign: Bool = false
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isImportingKsignPresenting = false
	@State private var _isPasswordAlertPresenting = false
	@State private var _errorMessage: String = ""
	@State private var _isErrorPresenting = false
	
	var saveButtonDisabled: Bool {
		if _isFromKsign {
			return _p12Data == nil || _provisionData == nil
		} else {
			return _p12URL == nil || _provisionURL == nil
		}
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("New Certificate"), displayMode: .inline) {
			Form {
				NBSection(.localized("Files")) {
					_importButton(.localized("Import Certificate File"), file: _p12URL, hasData: _p12Data) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("Import Provisioning File"), file: _provisionURL, hasData: _provisionData) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				NBSection(.localized("Password")) {
					SecureField(.localized("Enter Password"), text: $_p12Password)
				} footer: {
					Text(.localized("Enter the password associated with the private key. Leave it blank if theres no password required."))
				}
				
				Section {
					TextField(.localized("Nickname (Optional)"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.p12],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._p12URL = selectedFileURL
						self._isFromKsign = false
					}
				)
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [UTType.mobileProvision],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._provisionURL = selectedFileURL
						self._isFromKsign = false
					}
				)
			}
			.alert(isPresented: $_isPasswordAlertPresenting) {
				Alert(
					title: Text(.localized("Bad Password")),
					message: Text(.localized("Please check the password and try again.")),
					dismissButton: .default(Text(.localized("OK")))
				)
			}
			.alert(isPresented: $_isErrorPresenting) {
				Alert(
					title: Text(.localized("Import Error")),
					message: Text(_errorMessage),
					dismissButton: .default(Text(.localized("OK")))
				)
			}
		}
	}
}

// MARK: - Extension: View
extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		hasData: Data? = nil,
		action: @escaping () -> Void
	) -> some View {
		Button(title) {
			action()
		}
		.foregroundColor((file == nil && hasData == nil) ? .accentColor : .disabled())
		.disabled(file != nil || hasData != nil)
		.animation(.easeInOut(duration: 0.3), value: file != nil || hasData != nil)
	}
}

// MARK: - Extension: View (import)
extension CertificatesAddView {
	private func _saveCertificate() {
        guard
            let p12URL = _p12URL,
            let provisionURL = _provisionURL,
            FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
        else {
            _isPasswordAlertPresenting = true
            return
        }
        
        FR.handleCertificateFiles(
            p12URL: p12URL,
            provisionURL: provisionURL,
            p12Password: _p12Password,
            certificateName: _certificateName
        ) { _ in
            dismiss()
        }
	}
}



