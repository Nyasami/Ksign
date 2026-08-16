//
//  AboutNyaView.swift
//  ONEs
//
//  Created by ONEs.
//
import SwiftUI
import NimbleViews
// MARK: - View
struct AboutNyaView: View {
    @State private var shouldShowPatchNotes = false
    // MARK: - Body
    var body: some View {
        NBList(.localized("حول ONEs")) {
            // MARK: App Header
            Section {
                VStack(spacing: 10) {
                    if let image = UIImage(named: Bundle.main.iconFileName ?? "") {
                        Image(uiImage: image)
                            .appIconStyle(size: 80)
                    }
                    Text("ONEs")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.accent)
                    Text("متجر التطبيقات والأدوات")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("الإصدار")
                        Text(Bundle.main.version)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    Button {
                        shouldShowPatchNotes = true
                    } label: {
                        Text("ملاحظات التحديث")
                            .bg()
                    }
                    .font(.footnote)
                    .padding(.top, 4)
                    .tint(.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(EmptyView())
            // MARK: About
            NBSection(.localized("حول التطبيق")) {
                Text(
                    "ONEs هو متجر لتصفح وتحميل التطبيقات والألعاب والأدوات بسهولة، "
                    + "مع واجهة بسيطة وسريعة مصممة لتوفير تجربة استخدام مريحة."
                )
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            }
            // MARK: Developer
            NBSection(.localized("المطور")) {
                _credit(
                    name: "@VeilOfSuffering",
                    desc: "Developer",
                    github: "VeilOfSuffering"
                )
            }
            // MARK: Project
            NBSection(.localized("المشروع")) {
                Text(
                    "تم تطوير ONEs وتخصيصه ليكون تجربة مستقلة بواجهة وهوية خاصة، "
                    + "مع الحفاظ على الوظائف الأساسية التي يحتاجها المستخدم."
                )
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            }
            // MARK: Contact
            NBSection(.localized("الدعم والتواصل")) {
                Button {
                    if let url = URL(string: "https://t.me/VeilOfSufferingdev") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("دعم ONEs")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // MARK: Copyright
            NBSection(.localized("حقوق المشروع")) {
                Text(
                    "ONEs مشروع مستقل. تم تعديل وتخصيص التطبيق وتطوير واجهته "
                    + "ووظائفه بما يتناسب مع تجربة المستخدم."
                )
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            }
            // MARK: Bundle ID
            Section {
                Text(Bundle.main.bundleIdentifier ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowBackground(EmptyView())
        }
        .sheet(isPresented: $shouldShowPatchNotes) {
            PatchNotesView()
        }
    }
}
// MARK: - Extension
extension AboutNyaView {
    @ViewBuilder
    private func _credit(
        name: String?,
        desc: String?,
        github: String
    ) -> some View {
        FRIconCellView(
            title: name ?? github,
            subtitle: desc ?? "",
            iconUrl: URL(string: "https://github.com/\(github).png")!,
            trailing: AnyView(
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            )
        )
        .onTapGesture {
            if let url = URL(string: "https://github.com/\(github)") {
                UIApplication.shared.open(url)
            }
        }
    }
}
// MARK: - Patch Notes
private struct PatchNotesView: View {
    var body: some View {
        NavigationStack {
            NBList(.localized("ملاحظات التحديث")) {
                NBSection(.localized("ONEs")) {
                    Text(
                        "• تحسين واجهة التطبيق\n"
                        + "• تحديث هوية ONEs\n"
                        + "• تحسين صفحة الإعدادات\n"
                        + "• تحسين تجربة تصفح التطبيقات\n"
                        + "• تحسين الأداء والاستقرار"
                    )
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }
                NBSection(.localized("المطور")) {
                    Text("@VeilOfSuffering")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("تم") {
                        // NavigationStack handles dismissal when presented
                    }
                }
            }
        }
    }
}
