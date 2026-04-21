import SwiftUI

/// Per-host context settings: global offline mode and per-app default
/// English layer. The bundle ID list editor is intentionally low-level
/// (text field + add/remove). A richer "pick from running apps" picker is a
/// future Settings UX improvement.
struct PerAppSettingsView: View {
    @ObservedObject var model: BilineSettingsModel
    @State private var pendingBundleID: String = ""

    var body: some View {
        SettingsPage(title: "应用与单机模式") {
            SettingsCard {
                SettingsRow(
                    title: "单机模式",
                    subtitle: "无需网络，关闭英文预览/翻译等联网功能"
                ) {
                    Toggle("", isOn: $model.offlineMode).labelsHidden()
                }
            }

            SettingsCard {
                Text("默认使用英文的应用")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                ForEach(model.englishDefaultBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            model.removeEnglishDefaultBundleID(bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    Divider().padding(.leading, 20)
                }

                HStack {
                    TextField("输入 Bundle ID（如 com.apple.dt.Xcode）", text: $pendingBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("添加") {
                        model.addEnglishDefaultBundleID(pendingBundleID)
                        pendingBundleID = ""
                    }
                    .disabled(
                        pendingBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(20)
            }

            HStack {
                Button("保存") { model.savePerAppSettings() }
                Button("恢复默认") { model.resetPerAppSettingsToDefault() }
                if !model.perAppSaveStatus.isEmpty {
                    Text(model.perAppSaveStatus)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
