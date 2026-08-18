//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - واجهة الإعدادات
struct SettingsView: View {
    @AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0

    @FetchRequest(
        entity: CertificatePair.entity(),
        sortDescriptors: [
            NSSortDescriptor(
                keyPath: \CertificatePair.date,
                ascending: false
            )
        ],
        animation: .snappy
    )
    private var _certificates: FetchedResults<CertificatePair>

    // الشهادة المحددة حالياً
    private var selectedCertificate: CertificatePair? {
        guard
            _storedSelectedCert >= 0,
            _storedSelectedCert < _certificates.count
        else {
            return nil
        }

        return _certificates[_storedSelectedCert]
    }

    // رابط مستودع GitHub
    private let _githubUrl = "https://github.com/nyasami/ksign"

    // MARK: - المحتوى
    var body: some View {
        NBNavigationView(.localized("Settings")) {
            Form {

                // MARK: معلومات التطبيق والتواصل
                _feedback()

                // MARK: الشهادات
                NBSection(.localized("Certificates")) {

                    if let cert = selectedCertificate {
                        CertificatesCellView(cert: cert)
                    } else {
                        Text(.localized("No Certificate"))
                            .font(.footnote)
                            .foregroundColor(.disabled())
                    }

                    NavigationLink(
                        destination: CertificatesView()
                    ) {
                        Label(
                            .localized("Certificates"),
                            systemImage: "signature"
                        )
                    }

                } footer: {
                    Text(
                        .localized(
                            "Add and manage certificates used for signing applications."
                        )
                    )
                }

                // MARK: الميزات
                NBSection(.localized("Features")) {

                    NavigationLink(
                        destination: LogsView(
                            manager: LogsManager.shared
                        )
                    ) {
                        Label(
                            .localized("Logs"),
                            systemImage: "apple.terminal"
                        )
                    }

                    NavigationLink(
                        destination: AppFeaturesView()
                    ) {
                        Label(
                            .localized("App Features"),
                            systemImage: "sparkles"
                        )
                    }

                    NavigationLink(
                        destination: ConfigurationView()
                    ) {
                        Label(
                            .localized("Signing Options"),
                            systemImage: "gear"
                        )
                    }

                    NavigationLink(
                        destination: ArchiveView()
                    ) {
                        Label(
                            .localized("Archive & Extraction"),
                            systemImage: "archivebox"
                        )
                    }

                    NavigationLink(
                        destination: InstallationView()
                    ) {
                        Label(
                            .localized("Installation"),
                            systemImage: "server.rack"
                        )
                    }
                }

                // MARK: المجلدات
                _directories()

                // MARK: إعادة التعيين
                Section {
                    NavigationLink(
                        destination: ResetView()
                    ) {
                        Label(
                            .localized("Reset"),
                            systemImage: "trash"
                        )
                    }
                } footer: {
                    Text(
                        .localized(
                            "Reset the applications sources, certificates, apps, and general contents."
                        )
                    )
                }
            }
        }
    }
}

// MARK: - وظائف الإعدادات
extension SettingsView {

    // MARK: معلومات التطبيق والتواصل
    @ViewBuilder
    private func _feedback() -> some View {
        Section {

            // حول التطبيق
            NavigationLink(
                destination: AboutNyaView()
            ) {
                Label(
                    .localized("About"),
                    systemImage: "info.circle"
                )
            }

            // مستودع GitHub
            Button(
                .localized("GitHub Repository"),
                systemImage: "safari"
            ) {
                UIApplication.open(_githubUrl)
            }
        }
    }

    // MARK: المجلدات
    @ViewBuilder
    private func _directories() -> some View {
        NBSection(.localized("Misc")) {

            // فتح مجلد المستندات
            Button(
                .localized("Open Documents"),
                systemImage: "folder"
            ) {
                UIApplication.open(
                    URL.documentsDirectory.toSharedDocumentsURL()!
                )
            }

            // فتح مجلد الأرشيفات
            Button(
                .localized("Open Archives"),
                systemImage: "folder"
            ) {
                UIApplication.open(
                    FileManager.default.archives.toSharedDocumentsURL()!
                )
            }

        } footer: {
            Text(
                .localized(
                    "All of Ksign files except certificates are contained in the documents directory, here are some quick links to these."
                )
            )
        }
    }
}
