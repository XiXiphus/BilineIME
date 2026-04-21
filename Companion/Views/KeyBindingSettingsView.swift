import BilineCore
import SwiftUI

/// User-configurable key bindings. Phase 1 surfaces:
///   * Page-turn keys (`-/=`, `[/]`) for `nextRowOrPage` / `previousRowOrPage`.
///   * Single-keystroke candidate selection (`;` -> 2nd, `'` -> 3rd).
///
/// Each toggle here calls into `BilineSettingsModel+KeyBindingsPersistence`
/// so views stay declarative ("is this binding on?") and the policy mutation
/// lives in one place.
struct KeyBindingSettingsView: View {
    @ObservedObject var model: BilineSettingsModel

    private let pageTurnDefaultDash: [KeyChord] = [
        KeyChord(character: "-", keyCode: 27),
        KeyChord(character: "=", keyCode: 24),
    ]
    private let pageTurnDefaultBracket: [KeyChord] = [
        KeyChord(character: "[", keyCode: 33),
        KeyChord(character: "]", keyCode: 30),
    ]
    private let candidate2Semicolon = KeyChord(character: ";", keyCode: 41)
    private let candidate3Apostrophe = KeyChord(character: "'", keyCode: 39)

    var body: some View {
        SettingsPage(title: "按键") {
            SettingsCard {
                groupHeader("翻页找字")
                Toggle(
                    isOn: Binding(
                        get: {
                            model.isKeyBindingEnabled(
                                role: .previousRowOrPage,
                                chords: [pageTurnDefaultDash[0]]
                            )
                                && model.isKeyBindingEnabled(
                                    role: .nextRowOrPage, chords: [pageTurnDefaultDash[1]])
                        },
                        set: { newValue in
                            model.setKeyBinding(
                                role: .previousRowOrPage,
                                chords: [pageTurnDefaultDash[0]],
                                enabled: newValue
                            )
                            model.setKeyBinding(
                                role: .nextRowOrPage,
                                chords: [pageTurnDefaultDash[1]],
                                enabled: newValue
                            )
                        }
                    )
                ) {
                    HStack {
                        Text("减号 / 等号")
                        Spacer()
                        keyCapPair("-", "=")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                Divider().padding(.leading, 20)

                Toggle(
                    isOn: Binding(
                        get: {
                            model.isKeyBindingEnabled(
                                role: .previousRowOrPage,
                                chords: [pageTurnDefaultBracket[0]]
                            )
                                && model.isKeyBindingEnabled(
                                    role: .nextRowOrPage, chords: [pageTurnDefaultBracket[1]])
                        },
                        set: { newValue in
                            model.setKeyBinding(
                                role: .previousRowOrPage,
                                chords: [pageTurnDefaultBracket[0]],
                                enabled: newValue
                            )
                            model.setKeyBinding(
                                role: .nextRowOrPage,
                                chords: [pageTurnDefaultBracket[1]],
                                enabled: newValue
                            )
                        }
                    )
                ) {
                    HStack {
                        Text("左右中括号")
                        Spacer()
                        keyCapPair("[", "]")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            SettingsCard {
                groupHeader("候选词选择")
                Toggle(
                    isOn: Binding(
                        get: {
                            model.isKeyBindingEnabled(
                                role: .candidate2,
                                chords: [candidate2Semicolon]
                            )
                        },
                        set: { newValue in
                            model.setKeyBinding(
                                role: .candidate2,
                                chords: [candidate2Semicolon],
                                enabled: newValue
                            )
                        }
                    )
                ) {
                    HStack {
                        Text("用分号选择第 2 位候选词")
                        Spacer()
                        keyCap(";")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                Divider().padding(.leading, 20)

                Toggle(
                    isOn: Binding(
                        get: {
                            model.isKeyBindingEnabled(
                                role: .candidate3,
                                chords: [candidate3Apostrophe]
                            )
                        },
                        set: { newValue in
                            model.setKeyBinding(
                                role: .candidate3,
                                chords: [candidate3Apostrophe],
                                enabled: newValue
                            )
                        }
                    )
                ) {
                    HStack {
                        Text("用引号选择第 3 位候选词")
                        Spacer()
                        keyCap("'")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            HStack {
                Button("保存按键设置") { model.saveKeyBindings() }
                Button("恢复默认") { model.resetKeyBindingsToDefault() }
                if !model.keyBindingsSaveStatus.isEmpty {
                    Text(model.keyBindingsSaveStatus)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }

    private func keyCap(_ label: String) -> some View {
        Text(label)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor))
            )
    }

    private func keyCapPair(_ left: String, _ right: String) -> some View {
        HStack(spacing: 6) {
            keyCap(left)
            keyCap(right)
        }
    }
}
