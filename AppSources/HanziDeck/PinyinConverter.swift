import Foundation

enum PinyinConverter {
    private static let marks: [Character: [[Character]]] = [
        "a": [Array("aāáǎà"), Array("AĀÁǍÀ")],
        "e": [Array("eēéěè"), Array("EĒÉĚÈ")],
        "i": [Array("iīíǐì"), Array("IĪÍǏÌ")],
        "o": [Array("oōóǒò"), Array("OŌÓǑÒ")],
        "u": [Array("uūúǔù"), Array("UŪÚǓÙ")],
        "ü": [Array("üǖǘǚǜ"), Array("ÜǕǗǙǛ")]
    ]

    static func toneMarked(_ pinyin: String) -> String {
        pinyin
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { markToken(String($0)) }
            .joined(separator: " ")
    }

    static func syllableTokens(_ numberedPinyin: String) -> [String] {
        numberedPinyin
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { token in
                token.rangeOfCharacter(from: .letters) != nil
                    && token.rangeOfCharacter(from: .decimalDigits) != nil
            }
    }

    private static func markToken(_ original: String) -> String {
        guard let digitIndex = original.lastIndex(where: { "12345".contains($0) }),
              let tone = Int(String(original[digitIndex])) else {
            return original.replacingOccurrences(of: "u:", with: "ü")
                .replacingOccurrences(of: "U:", with: "Ü")
                .replacingOccurrences(of: "v", with: "ü")
                .replacingOccurrences(of: "V", with: "Ü")
        }

        var token = original
        token.remove(at: digitIndex)
        token = token.replacingOccurrences(of: "u:", with: "ü")
            .replacingOccurrences(of: "U:", with: "Ü")
            .replacingOccurrences(of: "v", with: "ü")
            .replacingOccurrences(of: "V", with: "Ü")

        guard tone < 5, let vowelIndex = toneVowelIndex(in: token) else {
            return token
        }

        let vowel = token[vowelIndex]
        let lower = Character(String(vowel).lowercased())
        guard let sets = marks[lower] else { return token }
        let set = vowel.isUppercase ? sets[1] : sets[0]
        token.replaceSubrange(vowelIndex...vowelIndex, with: String(set[tone]))
        return token
    }

    private static func toneVowelIndex(in token: String) -> String.Index? {
        let lower = token.lowercased()
        if let index = lower.firstIndex(of: "a") { return index }
        if let index = lower.firstIndex(of: "e") { return index }
        if let range = lower.range(of: "ou") { return range.lowerBound }
        return lower.lastIndex(where: { "aeiouü".contains($0) })
    }
}

private extension Character {
    var isUppercase: Bool {
        String(self) == String(self).uppercased()
            && String(self) != String(self).lowercased()
    }
}
