import Foundation

public struct PinyinInputSegmenter: Sendable {
    public let syllables: Set<String>
    private let maxSyllableLength: Int

    public init(syllables: Set<String> = []) {
        let normalizedSyllables = Set(syllables.map(Self.normalizeSyllable).filter { !$0.isEmpty })
        self.syllables = normalizedSyllables.union(Self.standardSyllables)
        self.maxSyllableLength = max(self.syllables.map(\.count).max() ?? 0, 1)
    }

    public func previousBlockBoundary(in input: String, from cursorIndex: Int) -> Int {
        let cursorIndex = clampedCursorIndex(cursorIndex, in: input)
        return blockBoundaries(in: input).last(where: { $0 < cursorIndex }) ?? 0
    }

    public func nextBlockBoundary(in input: String, from cursorIndex: Int) -> Int {
        let cursorIndex = clampedCursorIndex(cursorIndex, in: input)
        return blockBoundaries(in: input).first(where: { $0 > cursorIndex }) ?? input.count
    }

    public func blockBoundaries(in input: String) -> [Int] {
        guard !input.isEmpty else { return [0] }
        let characters = Array(input)
        var boundaries = [0]
        var index = 0

        while index < characters.count {
            if characters[index] == "'" {
                index += 1
                appendBoundary(index, to: &boundaries)
                continue
            }

            guard isASCIILetter(characters[index]) else {
                index += 1
                appendBoundary(index, to: &boundaries)
                continue
            }

            let start = index
            while index < characters.count, isASCIILetter(characters[index]) {
                index += 1
            }

            for length in greedyTokenLengths(in: Array(characters[start..<index])) {
                let boundary = (boundaries.last ?? start) + length
                appendBoundary(boundary, to: &boundaries)
            }

            if index < characters.count, characters[index] == "'" {
                index += 1
                if boundaries.count > 1 {
                    boundaries[boundaries.count - 1] = index
                } else {
                    appendBoundary(index, to: &boundaries)
                }
            }
        }

        appendBoundary(input.count, to: &boundaries)
        return boundaries
    }

    public func tokenizeAll(_ input: String, limit: Int = 128) -> [[String]] {
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

    public static func normalizeInput(_ input: String) -> String {
        normalizePinyin(input, keepsSpaces: false)
            .trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            .replacingOccurrences(of: "''+", with: "'", options: .regularExpression)
    }

    public static func normalizePinyin(_ text: String, keepsSpaces: Bool) -> String {
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

    private func clampedCursorIndex(_ index: Int, in input: String) -> Int {
        min(max(0, index), input.count)
    }

    private func appendBoundary(_ boundary: Int, to boundaries: inout [Int]) {
        let boundary = max(0, boundary)
        if boundaries.last != boundary {
            boundaries.append(boundary)
        }
    }

    private func greedyTokenLengths(in characters: [Character]) -> [Int] {
        guard !characters.isEmpty else { return [] }
        var lengths: [Int] = []
        var index = 0

        while index < characters.count {
            let longestLength = min(maxSyllableLength, characters.count - index)
            var matchedLength = 0
            for length in stride(from: longestLength, through: 1, by: -1) {
                let candidate = String(characters[index..<(index + length)])
                if syllables.contains(candidate) {
                    matchedLength = length
                    break
                }
            }
            let length = matchedLength == 0 ? 1 : matchedLength
            lengths.append(length)
            index += length
        }

        return lengths
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

    private func isASCIILetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
            character.unicodeScalars.count == 1,
            scalar.isASCII
        else {
            return false
        }
        let value = scalar.value
        return (65...90).contains(value) || (97...122).contains(value)
    }

    public static let standardSyllables: Set<String> = [
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
