import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case translation
    case inputSettings
    case appearance
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translation: "翻译配置"
        case .inputSettings: "输入设置"
        case .appearance: "外观"
        case .status: "状态"
        }
    }

    var symbolName: String {
        switch self {
        case .translation: "globe"
        case .inputSettings: "slider.horizontal.3"
        case .appearance: "paintpalette"
        case .status: "checkmark.circle"
        }
    }
}

struct SettingsRootView: View {
    @StateObject private var model = BilineSettingsModel()
    @State private var selection: SettingsSection? = .translation

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .onAppear {
            model.refresh()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .translation {
        case .translation:
            TranslationSettingsView(model: model)
        case .inputSettings:
            InputSettingsView(model: model)
        case .appearance:
            AppearanceSettingsView(model: model)
        case .status:
            StatusView(model: model)
        }
    }
}
