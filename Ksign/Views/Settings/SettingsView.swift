//
//  SettingsView.swift
//  ONEs
//
//  إعدادات تطبيق ONEs
//

import SwiftUI
import NimbleViews

// MARK: - View
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

    private var selectedCertificate: CertificatePair? {
        guard
            _storedSelectedCert >= 0,
            _storedSelectedCert < _certificates.count
        else {
            return nil
        }

        return _certificates[_storedSelectedCert]
    }

    // MARK: - Body
    var body: some View {
        NBNavigationView(.localized("الإعدادات")) {
            Form {

                // MARK: About
                _feedback()

                // MARK: Certificates
                NBSection(.localized("الشهادات")) {

                    if let cert = selectedCertificate {
                        CertificatesCellView(cert: cert)
                    } else {
                        Text(.localized("لا توجد شهادة"))
                            .font(.footnote)
                            .foregroundColor(.disabled())
                    }

                    NavigationLink(
                        destination: CertificatesView()
                    ) {
                        Label(
                            .localized("إدارة الشهادات"),
                            systemImage: "signature"
                        )
                    }

                } footer: {
                    Text(
                        .localized(
                            "إضافة وإدارة الشهادات المستخدمة لتوقيع التطبيقات."
                        )
                    )
                }

                // MARK: Features
                NBSection(.localized("الميزات")) {

                    NavigationLink(
                        destination: LogsView(
                            manager: LogsManager.shared
                        )
                    ) {
                        Label(
                            .localized("السجلات"),
                            systemImage: "apple.terminal"
                        )
                    }

                    NavigationLink(
                        destination: AppFeaturesView()
                    ) {
                        Label(
                            .localized("ميزات التطبيق"),
                            systemImage: "sparkles"
                        )
                    }

                    NavigationLink(
                        destination: ConfigurationView()
                    ) {
                        Label(
                            .localized("خيارات التوقيع"),
                            systemImage: "gear"
                        )
                    }

                    NavigationLink(
                        destination: ArchiveView()
                    ) {
                        Label(
                            .localized("الأرشيف والاستخراج"),
                            systemImage: "archivebox"
                        )
                    }

                    NavigationLink(
                        destination: InstallationView()
                    ) {
                        Label(
                            .localized("التثبيت"),
                            systemImage: "server.rack"
                        )
                    }
                }

                // MARK: Directories
                _directories()

                // MARK: Reset
                Section {
                    NavigationLink(
                        destination: ResetView()
                    ) {
                        Label(
                            .localized("إعادة الضبط"),
                            systemImage: "trash"
                        )
                    }
                } footer: {
                    Text(
                        .localized(
                            "إعادة ضبط مصادر التطبيقات والشهادات والتطبيقات والمحتويات العامة."
                        )
                    )
                }
            }
        }
    }
}

// MARK: - View Extension
extension SettingsView {

    // MARK: About
    @ViewBuilder
    private func _feedback() -> some View {
        Section {
            NavigationLink(
                destination: AboutNyaView()
            ) {
                Label(
                    .localized("حول ONEs"),
                    systemImage: "info.circle"
                )
            }
        }
    }

    // MARK: Directories
    @ViewBuilder
    private func _directories() -> some View {
        NBSection(.localized("متفرقات")) {

            Button(
                .localized("فتح المستندات"),
                systemImage: "folder"
            ) {
                UIApplication.open(
                    URL.documentsDirectory.toSharedDocumentsURL()!
                )
            }

            Button(
                .localized("فتح الأرشيف"),
                systemImage: "folder"
            ) {
                UIApplication.open(
                    FileManager.default.archives.toSharedDocumentsURL()!
                )
            }

        } footer: {
            Text(
                .localized(
                    "تحتوي مجلدات ONEs على الملفات الموجودة في مجلد المستندات، باستثناء الشهادات."
                )
            )
        }
    }
}
