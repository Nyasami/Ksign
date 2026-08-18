//
//  CertificatesView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit

// MARK: - View
struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	
	@State private var _isAddingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	//
	private var _bindingSelectedCert: Binding<Int>?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}
	
	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}
	
	// MARK: Body
	var body: some View {
		NBGrid {
			ForEach(Array(certificates.enumerated()), id: \.element.uuid) { index, cert in
				_cellButton(for: cert, at: index)
			}
		}
		.navigationTitle(.localized("Certificates"))
		.navigationBarTitleDisplayMode(.inline)
        .overlay {
            if certificates.isEmpty {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("No Certificates"), systemImage: "questionmark.folder.fill")
                    } description: {
                        Text(.localized("Get started signing by importing your first certificate."))
                    } actions: {
                        Button {
                            _isAddingPresenting = true
                        } label: {
							Text("Import").bg()
                        }
                    }
                }
            }
        }
		.toolbar {
			if _bindingSelectedCert == nil {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing
				) {
					_isAddingPresenting = true
				}
			}
			if certificates.count > 0 {
			NBToolbarButton(
				systemImage: "arrow.counterclockwise",
				style: .icon,
				placement: .topBarTrailing
				) {
					for cert in certificates {
						Storage.shared.revokagedCertificate(for: cert)
					}
				}
			}
		}
		.sheet(item: $_isSelectedInfoPresenting) { cert in
			CertificatesInfoView(cert: cert)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
				.presentationDetents([.medium])
		}
	}
}

extension CertificatesView {
	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		Button {
			_selectedCertBinding.wrappedValue = index
		} label: {
			CertificatesCellView(
				cert: cert
			)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: _cornerRadius)
					.fill(Color(uiColor: .quaternarySystemFill))
			)
			.overlay(
				RoundedRectangle(cornerRadius: _cornerRadius)
					.strokeBorder(
						_selectedCertBinding.wrappedValue == index ? Color.accentColor : Color.clear,
						lineWidth: 2
					)
			)
			.contextMenu {
				_contextActions(for: cert)
				Divider()
				_actions(for: cert)
			}
			.animation(.smooth, value: _selectedCertBinding.wrappedValue)
		}
		.buttonStyle(.plain)
	}
    
    private var _cornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 28.0
        } else {
            return 17.0
        }
    }
    
	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
		Button(role: .destructive) {
			if certificates.count == 1 {
                UIAlertController.showAlertWithOk(
                    title: .localized("You don't want to do this!"),
                    message: .localized("You don't want to delete your only certificate, right >.<?"),
                    isCancel: true
                )
            } else {
                Storage.shared.deleteCertificate(for: cert)
            }
		} label: {
			Label(.localized("Delete"), systemImage: "trash")
		}
	}
	
	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
		Button {
			_isSelectedInfoPresenting = cert
		} label: {
			Label(.localized("Get Info"), systemImage: "info.circle")
		}
	}
	

}
