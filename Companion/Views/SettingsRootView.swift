import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case status
    case translation
    case inputEngine
    case keyBindings
    case appearance
    case composingHelpers
    case perApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "状态"
        case .translation: "翻译"
        case .inputEngine: "输入引擎"
        case .keyBindings: "按键"
        case .appearance: "外观"
        case .composingHelpers: "输入辅助"
        case .perApp: "应用与单机模式"
        }
    }

    var symbolName: String {
        switch self {
        case .status: "checkmark.circle"
        case .translation: "globe"
        case .inputEngine: "keyboard"
        case .keyBindings: "command"
        case .appearance: "paintpalette"
        case .composingHelpers: "wand.and.stars"
        case .perApp: "macwindow"
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
        case .inputEngine:
            InputEngineSettingsView(model: model)
        case .keyBindings:
            KeyBindingSettingsView(model: model)
        case .appearance:
            AppearanceSettingsView(model: model)
        case .composingHelpers:
            ComposingHelpersSettingsView(model: model)
        case .perApp:
            PerAppSettingsView(model: model)
        }
    }
}
