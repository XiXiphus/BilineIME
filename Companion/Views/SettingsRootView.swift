import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case status
    case translation
    case input

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "状态"
        case .translation: "翻译"
        case .input: "输入"
        }
    }

    var symbolName: String {
        switch self {
        case .status: "checkmark.circle"
        case .translation: "globe"
        case .input: "keyboard"
        }
    }
}

struct SettingsRootView: View {
    @StateObject private var model = BilineSettingsModel()
    @State private var selection: SettingsSection? = .status

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
        switch selection ?? .status {
        case .status:
            StatusView(model: model)
        case .translation:
            TranslationSettingsView(model: model)
        case .input:
            InputSettingsView(model: model)
        }
    }
}
