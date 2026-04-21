import Foundation

struct PinyinTokenizer: Sendable {
    let syllables: Set<String>
    private let maxSyllableLength: Int

    init(syllables: Set<String>) {
        let normalizedSyllables = Set(syllables.map(Self.normalizeSyllable).filter { !$0.isEmpty })
        self.syllables = normalizedSyllables.union(Self.standardSyllables)
        self.maxSyllableLength = max(self.syllables.map(\.count).max() ?? 0, 1)
    }

    static func fromDictionaryFile(at url: URL) throws -> PinyinTokenizer {
        let contents = try String(contentsOf: url, encoding: .utf8)
        var syllables = Set<String>()

        for entry in parseDictionaryEntries(from: contents) {
            for token in entry.readingTokens {
                syllables.insert(token)
            }
        }

        return PinyinTokenizer(syllables: syllables)
    }

    func tokenize(_ input: String) -> [String]? {
        tokenizeAll(input, limit: 1).first
    }

    func tokenizeAll(_ input: String, limit: Int = 128) -> [[String]] {
        let normalizedInput = Self.normalizeInput(input)
        guard !normalizedInput.isEmpty else {
            return []
        }

        let chunks = normalizedInput.split(separator: "'", omittingEmptySubsequences: false).map(
            String.init)
        var combined: [[String]] = [[]]

        for chunk in chunks {
            let chunkTokenizations = tokenizeChunkAll(chunk, limit: limit)
            guard !chunkTokenizations.isEmpty else {
                return []
            }

            var nextCombined: [[String]] = []
            for prefix in combined {
                for suffix in chunkTokenizations {
                    nextCombined.append(prefix + suffix)
                    if nextCombined.count >= limit { break }
                }
                if nextCombined.count >= limit { break }
            }
            combined = nextCombined
        }

        return combined
    }

    func readingTokens(from text: String) -> [String]? {
        let normalized = Self.normalizePinyin(text, keepsSpaces: true)
        guard !normalized.isEmpty else { return [] }
        let explicitTokens =
            normalized
            .split(whereSeparator: { $0 == " " || $0 == "'" })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !explicitTokens.isEmpty else { return [] }
        if explicitTokens.allSatisfy({ syllables.contains($0) }) {
            return explicitTokens
        }

        return tokenize(normalized.replacingOccurrences(of: " ", with: "'"))
    }

    static func normalizeInput(_ input: String) -> String {
        normalizePinyin(input, keepsSpaces: false)
            .trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            .replacingOccurrences(of: "''+", with: "'", options: .regularExpression)
    }

    static func normalizePinyin(_ text: String, keepsSpaces: Bool) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for scalar in text.unicodeScalars {
            if scalar == "'" || scalar == "’" || scalar == "`" || scalar == "´" {
                result.append("'")
                continue
            }
            if keepsSpaces, CharacterSet.whitespacesAndNewlines.contains(scalar) {
                result.append(" ")
                continue
            }
            if let ascii = normalizedASCIIScalar(for: scalar) {
                result.unicodeScalars.append(ascii)
            }
        }

        if keepsSpaces {
            return
                result
                .split(whereSeparator: { $0 == " " })
                .joined(separator: " ")
        }
        return result
    }

    private static func normalizeSyllable(_ input: String) -> String {
        normalizePinyin(input, keepsSpaces: false)
    }

    private static func normalizedASCIIScalar(for scalar: UnicodeScalar) -> UnicodeScalar? {
        switch scalar {
        case "A", "Ā", "Á", "Ǎ", "À", "ā", "á", "ǎ", "à", "a": return "a"
        case "B", "b": return "b"
        case "C", "c": return "c"
        case "D", "d": return "d"
        case "E", "Ē", "É", "Ě", "È", "ê", "ē", "é", "ě", "è", "e": return "e"
        case "F", "f": return "f"
        case "G", "g": return "g"
        case "H", "h": return "h"
        case "I", "Ī", "Í", "Ǐ", "Ì", "ī", "í", "ǐ", "ì", "i": return "i"
        case "J", "j": return "j"
        case "K", "k": return "k"
        case "L", "l": return "l"
        case "M", "Ḿ", "m", "ḿ": return "m"
        case "N", "Ń", "Ň", "Ǹ", "n", "ń", "ň", "ǹ": return "n"
        case "O", "Ō", "Ó", "Ǒ", "Ò", "ō", "ó", "ǒ", "ò", "o": return "o"
        case "P", "p": return "p"
        case "Q", "q": return "q"
        case "R", "r": return "r"
        case "S", "s": return "s"
        case "T", "t": return "t"
        case "U", "Ū", "Ú", "Ǔ", "Ù", "ū", "ú", "ǔ", "ù", "u": return "u"
        case "Ü", "Ǖ", "Ǘ", "Ǚ", "Ǜ", "ü", "ǖ", "ǘ", "ǚ", "ǜ", "V", "v": return "v"
        case "W", "w": return "w"
        case "X", "x": return "x"
        case "Y", "y": return "y"
        case "Z", "z": return "z"
        default: return nil
        }
    }

    private func tokenizeChunkAll(_ chunk: String, limit: Int) -> [[String]] {
        guard !chunk.isEmpty else { return [[]] }

        let characters = Array(chunk)
        var memo: [Int: [[String]]] = [:]

        func search(from index: Int) -> [[String]] {
            if index == characters.count { return [[]] }
            if let cached = memo[index] { return cached }

            var results: [[String]] = []
            let longestLength = min(maxSyllableLength, characters.count - index)
            for length in stride(from: longestLength, through: 1, by: -1) {
                let candidate = String(characters[index..<(index + length)])
                guard syllables.contains(candidate) else { continue }
                for tail in search(from: index + length) {
                    results.append([candidate] + tail)
                    if results.count >= limit {
                        memo[index] = results
                        return results
                    }
                }
            }

            memo[index] = results
            return results
        }

        return search(from: 0)
    }

    private static let standardSyllables: Set<String> = [
        "a", "ai", "an", "ang", "ao",
        "ba", "bai", "ban", "bang", "bao", "bei", "ben", "beng", "bi", "bian", "biao", "bie", "bin",
        "bing", "bo", "bu",
        "ca", "cai", "can", "cang", "cao", "ce", "cen", "ceng", "cha", "chai", "chan", "chang",
        "chao", "che", "chen", "cheng", "chi", "chong", "chou", "chu", "chua", "chuai", "chuan",
        "chuang", "chui", "chun", "chuo", "ci", "cong", "cou", "cu", "cuan", "cui", "cun", "cuo",
        "da", "dai", "dan", "dang", "dao", "de", "dei", "den", "deng", "di", "dia", "dian", "diao",
        "die", "ding", "diu", "dong", "dou", "du", "duan", "dui", "dun", "duo",
        "e", "ei", "en", "eng", "er",
        "fa", "fan", "fang", "fei", "fen", "feng", "fo", "fou", "fu",
        "ga", "gai", "gan", "gang", "gao", "ge", "gei", "gen", "geng", "gong", "gou", "gu", "gua",
        "guai", "guan", "guang", "gui", "gun", "guo",
        "ha", "hai", "han", "hang", "hao", "he", "hei", "hen", "heng", "hong", "hou", "hu", "hua",
        "huai", "huan", "huang", "hui", "hun", "huo",
        "ji", "jia", "jian", "jiang", "jiao", "jie", "jin", "jing", "jiong", "jiu", "ju", "juan",
        "jue", "jun",
        "ka", "kai", "kan", "kang", "kao", "ke", "kei", "ken", "keng", "kong", "kou", "ku", "kua",
        "kuai", "kuan", "kuang", "kui", "kun", "kuo",
        "la", "lai", "lan", "lang", "lao", "le", "lei", "leng", "li", "lia", "lian", "liang",
        "liao", "lie", "lin", "ling", "liu", "lo", "long", "lou", "lu", "luan", "lun", "luo", "lv",
        "lve",
        "ma", "mai", "man", "mang", "mao", "me", "mei", "men", "meng", "mi", "mian", "miao", "mie",
        "min", "ming", "miu", "mo", "mou", "mu",
        "na", "nai", "nan", "nang", "nao", "ne", "nei", "nen", "neng", "ni", "nian", "niang",
        "niao", "nie", "nin", "ning", "niu", "nong", "nou", "nu", "nuan", "nun", "nuo", "nv", "nve",
        "o", "ou",
        "pa", "pai", "pan", "pang", "pao", "pei", "pen", "peng", "pi", "pian", "piao", "pie", "pin",
        "ping", "po", "pou", "pu",
        "qi", "qia", "qian", "qiang", "qiao", "qie", "qin", "qing", "qiong", "qiu", "qu", "quan",
        "que", "qun",
        "ran", "rang", "rao", "re", "ren", "reng", "ri", "rong", "rou", "ru", "rua", "ruan", "rui",
        "run", "ruo",
        "sa", "sai", "san", "sang", "sao", "se", "sen", "seng", "sha", "shai", "shan", "shang",
        "shao", "she", "shei", "shen", "sheng", "shi", "shou", "shu", "shua", "shuai", "shuan",
        "shuang", "shui", "shun", "shuo", "si", "song", "sou", "su", "suan", "sui", "sun", "suo",
        "ta", "tai", "tan", "tang", "tao", "te", "teng", "ti", "tian", "tiao", "tie", "ting",
        "tong", "tou", "tu", "tuan", "tui", "tun", "tuo",
        "wa", "wai", "wan", "wang", "wei", "wen", "weng", "wo", "wu",
        "xi", "xia", "xian", "xiang", "xiao", "xie", "xin", "xing", "xiong", "xiu", "xu", "xuan",
        "xue", "xun",
        "ya", "yan", "yang", "yao", "ye", "yi", "yin", "ying", "yo", "yong", "you", "yu", "yuan",
        "yue", "yun",
        "za", "zai", "zan", "zang", "zao", "ze", "zei", "zen", "zeng", "zha", "zhai", "zhan",
        "zhang", "zhao", "zhe", "zhei", "zhen", "zheng", "zhi", "zhong", "zhou", "zhu", "zhua",
        "zhuai", "zhuan", "zhuang", "zhui", "zhun", "zhuo", "zi", "zong", "zou", "zu", "zuan",
        "zui", "zun", "zuo",
    ]
}

private struct RimeDictionaryEntry: Sendable {
    let surface: String
    let readingTokens: [String]
    let reading: String
    let weight: Int

    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" || trimmed == "..." {
            return nil
        }
        if trimmed.contains(":") && !trimmed.contains("\t") { return nil }

        let fields = trimmed.split(separator: "\t", omittingEmptySubsequences: true).map(
            String.init)
        guard fields.count >= 2 else { return nil }
        let tokens = PinyinTokenizer.normalizePinyin(fields[1], keepsSpaces: true)
            .split(whereSeparator: { $0 == " " || $0 == "'" })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }

        self.surface = fields[0].applyingRimeLexiconSimplifiedFallbacks()
        self.readingTokens = tokens
        self.reading = tokens.joined(separator: " ")
        self.weight = fields.dropFirst(2).compactMap { Int($0) }.first ?? 0
    }
}

extension String {
    func applyingRimeLexiconSimplifiedFallbacks() -> String {
        let table: [Character: String] = [
            "學": "学", "習": "习", "國": "国", "語": "语", "電": "电", "腦": "脑", "網": "网", "絡": "络",
            "軟": "软", "體": "体", "開": "开", "發": "发", "數": "数", "據": "据", "庫": "库", "雲": "云",
            "臺": "台", "後": "后", "裏": "里", "裡": "里", "麼": "么", "為": "为", "與": "与",
            "這": "这", "個": "个", "們": "们", "會": "会", "來": "来", "時": "时", "間": "间", "現": "现",
            "魚": "鱼",
            "讓": "让", "對": "对", "應": "应", "問": "问", "題": "题", "無": "无", "線": "线", "測": "测",
            "試": "试", "設": "设", "計": "计", "產": "产", "業": "业", "機": "机", "車": "车", "書": "书",
            "長": "长", "門": "门", "風": "风", "馬": "马", "東": "东", "區": "区", "醫": "医", "愛": "爱",
            "聽": "听", "說": "说", "買": "买", "賣": "卖", "讀": "读", "寫": "写", "萬": "万", "過": "过",
            "還": "还", "進": "进", "連": "连", "選": "选", "擇": "择", "號": "号", "頁": "页", "顯": "显",
            "覽": "览", "譯": "译", "雙": "双", "層": "层", "詞": "词", "頻": "频", "碼": "码", "標": "标",
            "點": "点", "輸": "输", "獨": "独", "類": "类", "關": "关", "鍵": "键", "態": "态", "壓": "压",
            "縮": "缩", "檔": "档", "佈": "布", "優": "优", "險": "险", "損": "损", "貝": "贝", "葉": "叶",
            "灣": "湾", "廣": "广", "華": "华", "劃": "划", "實": "实", "驗": "验", "證": "证", "論": "论",
            "斷": "断", "構": "构", "潔": "洁",
        ]
        return reduce(into: "") { result, character in
            result.append(table[character] ?? String(character))
        }
    }
}

struct RimeConsumption: Sendable, Equatable {
    let tokenCount: Int
    let tokens: [String]
}

private func parseDictionaryEntries(from contents: String) -> [RimeDictionaryEntry] {
    contents
        .split(whereSeparator: \.isNewline)
        .compactMap { RimeDictionaryEntry(line: String($0)) }
}

struct RimeLexicon: Sendable {
    struct Entry: Sendable, Equatable, Hashable {
        let surface: String
        let reading: String
        let readingTokens: [String]
        let weight: Int
    }

    let entriesByReading: [String: [Entry]]
    let entriesBySurface: [String: [Entry]]

    static func fromDictionaryFiles(at urls: [URL]) throws -> RimeLexicon {
        var byReading: [String: [Entry]] = [:]
        var bySurface: [String: [Entry]] = [:]
        var seen = Set<Entry>()

        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let contents = try String(contentsOf: url, encoding: .utf8)
            for line in contents.split(whereSeparator: \.isNewline) {
                guard let record = RimeDictionaryEntry(line: String(line)) else { continue }
                let entry = Entry(
                    surface: record.surface,
                    reading: record.reading,
                    readingTokens: record.readingTokens,
                    weight: record.weight
                )
                guard seen.insert(entry).inserted else { continue }
                byReading[entry.reading, default: []].append(entry)
                bySurface[entry.surface, default: []].append(entry)
            }
        }

        for key in byReading.keys { byReading[key]?.sort(by: Self.entrySort) }
        for key in bySurface.keys { bySurface[key]?.sort(by: Self.entrySort) }
        return RimeLexicon(entriesByReading: byReading, entriesBySurface: bySurface)
    }

    func consumption(
        forSurface surface: String,
        rawInput: String,
        comment: String?,
        tokenizer: PinyinTokenizer
    ) -> RimeConsumption {
        let tokenizations = tokenizer.tokenizeAll(rawInput)
        guard !tokenizations.isEmpty else {
            let tokens = tokenizer.readingTokens(from: comment ?? "") ?? []
            return RimeConsumption(tokenCount: tokens.count, tokens: tokens)
        }

        if let commentTokens = tokenizer.readingTokens(from: comment ?? ""), !commentTokens.isEmpty
        {
            for tokens in tokenizations where tokens.count >= commentTokens.count {
                if Array(tokens.prefix(commentTokens.count)) == commentTokens {
                    return RimeConsumption(tokenCount: commentTokens.count, tokens: tokens)
                }
            }
        }

        let normalizedSurface = surface.applyingRimeLexiconSimplifiedFallbacks()
        var best = RimeConsumption(tokenCount: 0, tokens: tokenizations[0])
        for tokens in tokenizations {
            for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
                let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
                let matchesSurface =
                    entriesByReading[reading]?.contains(where: {
                        $0.surface == normalizedSurface
                    }) == true
                if matchesSurface, prefixCount > best.tokenCount {
                    best = RimeConsumption(tokenCount: prefixCount, tokens: tokens)
                    break
                }
            }
        }

        return best
    }

    func coverageMap(for rawInput: String, tokenizer: PinyinTokenizer) -> [String: Int] {
        var coverage: [String: Int] = [:]
        for tokens in tokenizer.tokenizeAll(rawInput) {
            for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
                let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
                guard let entries = entriesByReading[reading] else { continue }
                for entry in entries {
                    coverage[entry.surface] = max(coverage[entry.surface] ?? 0, prefixCount)
                }
            }
        }
        return coverage
    }

    func consumedTokenCount(
        surface: String,
        comment: String,
        rawInput: String,
        tokenizer: PinyinTokenizer
    ) -> Int {
        consumption(
            forSurface: surface,
            rawInput: rawInput,
            comment: comment.isEmpty ? nil : comment,
            tokenizer: tokenizer
        ).tokenCount
    }

    struct Match: Sendable, Equatable {
        let entry: Entry
        let consumedTokenCount: Int
        let tokens: [String]
    }

    func prefixMatches(for rawInput: String, tokenizer: PinyinTokenizer) -> [Match] {
        var bestBySurface: [String: Match] = [:]
        for tokens in tokenizer.tokenizeAll(rawInput) {
            for prefixCount in stride(from: tokens.count, through: 1, by: -1) {
                let reading = Array(tokens.prefix(prefixCount)).joined(separator: " ")
                guard let entries = entriesByReading[reading] else { continue }
                for entry in entries {
                    let match = Match(entry: entry, consumedTokenCount: prefixCount, tokens: tokens)
                    if let existing = bestBySurface[entry.surface] {
                        if Self.matchSort(match, existing) {
                            bestBySurface[entry.surface] = match
                        }
                    } else {
                        bestBySurface[entry.surface] = match
                    }
                }
            }
        }
        return bestBySurface.values.sorted(by: Self.matchSort)
    }

    private static func matchSort(_ lhs: Match, _ rhs: Match) -> Bool {
        let lhsConsumesWholeInput = lhs.consumedTokenCount == lhs.tokens.count
        let rhsConsumesWholeInput = rhs.consumedTokenCount == rhs.tokens.count
        if lhsConsumesWholeInput != rhsConsumesWholeInput {
            return lhsConsumesWholeInput
        }

        if !lhsConsumesWholeInput, lhs.consumedTokenCount != rhs.consumedTokenCount {
            return lhs.consumedTokenCount < rhs.consumedTokenCount
        }

        if lhs.entry.weight != rhs.entry.weight { return lhs.entry.weight > rhs.entry.weight }
        if lhs.entry.surface.count != rhs.entry.surface.count {
            return lhs.entry.surface.count > rhs.entry.surface.count
        }
        return lhs.entry.surface < rhs.entry.surface
    }

    private static func entrySort(_ lhs: Entry, _ rhs: Entry) -> Bool {
        if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
        if lhs.readingTokens.count != rhs.readingTokens.count {
            return lhs.readingTokens.count > rhs.readingTokens.count
        }
        if lhs.surface.count != rhs.surface.count { return lhs.surface.count > rhs.surface.count }
        return lhs.surface < rhs.surface
    }
}
