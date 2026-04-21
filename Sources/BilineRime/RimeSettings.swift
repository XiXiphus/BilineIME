import BilineCore

struct RimeSettings: Sendable, Equatable {
    let pageSize: Int
    let fuzzyPinyinEnabled: Bool
    let characterForm: CharacterForm

    var schemaID: String {
        switch characterForm {
        case .simplified:
            return "biline_pinyin_simp"
        case .traditional:
            return "biline_pinyin_trad"
        }
    }

    var userDictionaryName: String {
        schemaID
    }
}
