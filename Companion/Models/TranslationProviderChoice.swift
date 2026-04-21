enum TranslationProviderChoice: String, CaseIterable, Identifiable {
    case off
    case aliyun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "关闭"
        case .aliyun: "阿里云机器翻译"
        }
    }
}
