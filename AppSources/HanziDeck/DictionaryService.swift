import Foundation
import SQLite3

struct DictionaryEntry: Identifiable, Hashable {
    let id: Int64
    let traditional: String
    let simplified: String
    let numberedPinyin: String
    let rawMeaning: String

    var displayPinyin: String { PinyinConverter.toneMarked(numberedPinyin) }
    var meaning: String { CEDICTDefinitionCleaner.clean(rawMeaning) }
}

struct ParsedCEDICTEntry: Equatable {
    let traditional: String
    let simplified: String
    let pinyin: String
    let meaning: String
}

enum CEDICTLineParser {
    static func parse(_ line: String) -> ParsedCEDICTEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
              let bracketOpen = trimmed.firstIndex(of: "["),
              let bracketClose = trimmed[bracketOpen...].firstIndex(of: "]") else {
            return nil
        }

        let head = trimmed[..<bracketOpen].split(whereSeparator: { $0.isWhitespace })
        guard head.count >= 2 else { return nil }
        let pinyin = trimmed[trimmed.index(after: bracketOpen)..<bracketClose]
        let definitionStart = trimmed.index(after: bracketClose)
        let definitions = trimmed[definitionStart...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
        let meaning = CEDICTDefinitionCleaner.clean(definitions)

        guard !meaning.isEmpty else { return nil }
        return ParsedCEDICTEntry(
            traditional: String(head[0]),
            simplified: String(head[1]),
            pinyin: String(pinyin),
            meaning: meaning
        )
    }
}

enum CEDICTDefinitionCleaner {
    static func clean(_ rawMeaning: String, maximumDefinitions: Int = 3) -> String {
        guard maximumDefinitions > 0 else { return "" }
        return rawMeaning
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isDictionaryMetadata($0) }
            .prefix(maximumDefinitions)
            .joined(separator: "; ")
    }

    private static func isDictionaryMetadata(_ definition: String) -> Bool {
        let normalized = definition.lowercased()
        return normalized.hasPrefix("cl:")
            || normalized.hasPrefix("classifier:")
            || normalized.hasPrefix("also pr.")
            || normalized.hasPrefix("also pronounced")
            || normalized.hasPrefix("taiwan pr.")
            || normalized.hasPrefix("pr. ")
    }
}

@MainActor
final class DictionaryService: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var errorMessage: String?

    private let databaseHandle = SQLiteDatabaseHandle()

    init() {
        openDatabase()
    }

    func lookup(_ text: String, limit: Int = 40) -> [DictionaryEntry] {
        guard let database = databaseHandle.raw else { return [] }
        let sql = """
            SELECT id, traditional, simplified, pinyin, meaning
            FROM entries
            WHERE traditional = ?1 OR simplified = ?1
            ORDER BY CASE WHEN simplified = ?1 THEN 0 ELSE 1 END, id
            LIMIT ?2
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, text, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var entries: [DictionaryEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            entries.append(
                DictionaryEntry(
                    id: sqlite3_column_int64(statement, 0),
                    traditional: string(statement, column: 1),
                    simplified: string(statement, column: 2),
                    numberedPinyin: string(statement, column: 3),
                    rawMeaning: string(statement, column: 4)
                )
            )
        }
        return entries
    }

    func cleanedMeaning(for hanzi: String, pinyin: String, storedMeaning: String) -> String? {
        guard let entry = lookup(hanzi).first(where: {
            $0.displayPinyin == pinyin && $0.rawMeaning == storedMeaning
        }), entry.meaning != storedMeaning else {
            return nil
        }
        return entry.meaning
    }

    func characterDrafts(for hanzi: String, entry: DictionaryEntry?) -> [CharacterDraft] {
        let glyphs = hanzi.map(String.init).filter { $0.containsHanIdeograph }
        let tokens = entry.map { PinyinConverter.syllableTokens($0.numberedPinyin) } ?? []
        let aligned = tokens.count == glyphs.count

        return glyphs.enumerated().map { index, glyph in
            let pinyin: String
            if aligned {
                pinyin = PinyinConverter.toneMarked(tokens[index])
            } else {
                let firstToken = lookup(glyph).first
                    .flatMap { PinyinConverter.syllableTokens($0.numberedPinyin).first }
                pinyin = firstToken.map(PinyinConverter.toneMarked) ?? ""
            }
            return CharacterDraft(glyph: glyph, pinyin: pinyin, position: index)
        }
    }

    func detectedWords(from recognizedLines: [String]) -> [String] {
        var seen: Set<String> = []
        var words: [String] = []

        for run in recognizedLines.flatMap(\.hanIdeographRuns) {
            let candidates = lookup(run).isEmpty ? segment(run) : [run]
            for candidate in candidates where seen.insert(candidate).inserted {
                words.append(candidate)
            }
        }
        return words
    }

    private func segment(_ text: String) -> [String] {
        let glyphs = Array(text)
        var result: [String] = []
        var index = 0

        while index < glyphs.count {
            let maximumLength = min(12, glyphs.count - index)
            var match: String?
            for length in stride(from: maximumLength, through: 1, by: -1) {
                let candidate = String(glyphs[index..<(index + length)])
                if !lookup(candidate, limit: 1).isEmpty {
                    match = candidate
                    break
                }
            }
            let selected = match ?? String(glyphs[index])
            result.append(selected)
            index += selected.count
        }
        return result
    }

    private func openDatabase() {
        #if SWIFT_PACKAGE
        let resourceBundle = Bundle.module
        #else
        let resourceBundle = Bundle.main
        #endif
        guard let url = resourceBundle.url(forResource: "cedict", withExtension: "sqlite") else {
            errorMessage = "The bundled dictionary could not be found."
            return
        }

        var handle: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK else {
            if let handle { sqlite3_close(handle) }
            errorMessage = "The bundled dictionary could not be opened."
            return
        }
        databaseHandle.raw = handle
        isAvailable = true
    }

    private func string(_ statement: OpaquePointer, column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class SQLiteDatabaseHandle: @unchecked Sendable {
    var raw: OpaquePointer?

    deinit {
        if let raw { sqlite3_close(raw) }
    }
}

extension String {
    var containsHanIdeograph: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x20000...0x2FA1F, 0x30000...0x323AF:
                true
            default:
                false
            }
        }
    }

    var hanIdeographRuns: [String] {
        var runs: [String] = []
        var current = ""
        for character in self {
            let value = String(character)
            if value.containsHanIdeograph {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }
}
