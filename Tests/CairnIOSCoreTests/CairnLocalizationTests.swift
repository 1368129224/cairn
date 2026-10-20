import Foundation
import Testing
import CairnCore
@testable import CairnIOSCore

@Suite("Localization")
struct CairnLocalizationTests {

    // MARK: - Resource table integrity

    @Test("en and zh-Hans Localizable.strings have zero duplicate keys and 100% key parity")
    func stringsTablesHaveNoDuplicatesAndFullParity() throws {
        let enURL = try #require(Self.stringsFileURL(lproj: "en"), "en.lproj/Localizable.strings not found")
        let zhURL = try #require(Self.stringsFileURL(lproj: "zh-Hans"), "zh-Hans.lproj/Localizable.strings not found")

        let enParsed = try Self.parseStringsFile(at: enURL)
        let zhParsed = try Self.parseStringsFile(at: zhURL)

        #expect(enParsed.duplicates.isEmpty, "Duplicate keys in en.lproj: \(enParsed.duplicates.sorted())")
        #expect(zhParsed.duplicates.isEmpty, "Duplicate keys in zh-Hans.lproj: \(zhParsed.duplicates.sorted())")
        #expect(enParsed.entries.count > 700, "Expected full en string table")

        let enKeys = Set(enParsed.entries.keys)
        let zhKeys = Set(zhParsed.entries.keys)
        #expect(enKeys.subtracting(zhKeys).isEmpty, "Keys missing from zh-Hans.lproj: \(enKeys.subtracting(zhKeys).sorted())")
        #expect(zhKeys.subtracting(enKeys).isEmpty, "Extra keys in zh-Hans.lproj not in en.lproj: \(zhKeys.subtracting(enKeys).sorted())")

        for (key, value) in zhParsed.entries {
            #expect(!value.isEmpty, "Empty zh-Hans translation for key: \(key)")
        }
    }

    @Test("en and zh-Hans Localizable.strings preserve matching format specifiers")
    func stringsTablesPreserveFormatSpecifiers() throws {
        let enURL = try #require(Self.stringsFileURL(lproj: "en"))
        let zhURL = try #require(Self.stringsFileURL(lproj: "zh-Hans"))
        let enEntries = try Self.parseStringsFile(at: enURL).entries
        let zhEntries = try Self.parseStringsFile(at: zhURL).entries

        for (key, enValue) in enEntries {
            guard let zhValue = zhEntries[key] else { continue }
            #expect(
                Self.formatSpecifiers(in: enValue) == Self.formatSpecifiers(in: zhValue),
                "Format specifier mismatch for key '\(key)': en=\(enValue) zh=\(zhValue)"
            )
        }
    }

    // MARK: - Runtime bundle lookup & formatting

    @Test("Bundle lookup resolves English and Simplified Chinese without global mutable state")
    func bundleLookupAndFallback() {
        #expect(AppLanguage.chineseSimplified.t("Status") == "状态")
        #expect(AppLanguage.chineseSimplified.t("Runs") == "运行记录")
        #expect(AppLanguage.chineseSimplified.t("Settings") == "设置")
        #expect(AppLanguage.chineseSimplified.t("QUICK SETTINGS") == "快捷设置")
        #expect(AppLanguage.chineseSimplified.t("Cautious") == "谨慎模式")
        #expect(AppLanguage.chineseSimplified.t("Balanced") == "平衡模式")
        #expect(AppLanguage.chineseSimplified.t("Autonomous") == "自主模式")
        #expect(AppLanguage.chineseSimplified.t("Quarantine window") == "隔离期")
        #expect(AppLanguage.chineseSimplified.t("Sync detail") == "同步详情")
        #expect(AppLanguage.chineseSimplified.t("Find missed deletions") == "查找遗漏的删除")
        #expect(AppLanguage.chineseSimplified.t("Archived history") == "归档历史")
        #expect(AppLanguage.chineseSimplified.t("unknown-localization-key") == "unknown-localization-key")

        #expect(AppLanguage.english.t("Status") == "Status")
        #expect(AppLanguage.english.t("Cautious") == "Cautious")
        #expect(AppLanguage.english.t("Quarantine window") == "Quarantine window")

        // System mode resolves based on preferredLanguages without global state.
        #expect(CairnL10n.string("Status", language: .system, preferredLanguages: ["zh-Hans-CN"]) == "状态")
        #expect(CairnL10n.string("Status", language: .system, preferredLanguages: ["en-US"]) == "Status")
    }

    @Test("Immich proper nouns remain in English in Chinese translations")
    func immichProperNounsStayEnglish() {
        #expect(AppLanguage.chineseSimplified.t("API key") == "API Key")
        #expect(AppLanguage.chineseSimplified.t("Live Photos") == "Live Photos")
        #expect(AppLanguage.chineseSimplified.t("Move to Trash").contains("Trash"))
        #expect(AppLanguage.chineseSimplified.t("Ready to trash").contains("Trash"))
        #expect(AppLanguage.chineseSimplified.t("Thumbhash cache cap").contains("Thumbhash"))
        #expect(AppLanguage.chineseSimplified.t("Find these in Immich's Tags view. Assets stay in Trash for 30 days.").contains("Tags"))
        #expect(AppLanguage.chineseSimplified.t("Find these in Immich's Tags view. Assets stay in Trash for 30 days.").contains("Trash"))
    }

    @Test("Formatted strings handle argument ordering safely in both languages")
    func formattedStringsAndPositionalReordering() {
        #expect(
            AppLanguage.english.f("stops above %@ past %@ items", "1.0%", "5")
                == "stops above 1.0% past 5 items"
        )
        #expect(
            AppLanguage.chineseSimplified.f("stops above %@ past %@ items", "1.0%", "5")
                == "超过 5 项且高于 1.0% 时终止"
        )
        #expect(
            AppLanguage.chineseSimplified.f("Downloading %@%%", "42")
                == "正在下载 42%"
        )
        #expect(
            AppLanguage.english.f("Downloading %@%%", "42")
                == "Downloading 42%"
        )
    }

    @MainActor
    @Test("Relative time and duration helpers localize cleanly while keeping English default")
    func localizedTimeAndDurationHelpers() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let twoHoursAgo = now.addingTimeInterval(-2 * 3600)

        #expect(CairnTimeHelpers.relativeTime(twoHoursAgo, now: now) == "2h ago")
        #expect(CairnTimeHelpers.relativeTime(twoHoursAgo, now: now, language: .chineseSimplified) == "2 小时前")

        let inThreeDays = Date().addingTimeInterval(2.5 * 86_400)
        #expect(StatusScreen.relativeDay(inThreeDays) == "3 days")
        #expect(StatusScreen.relativeDay(inThreeDays, language: .chineseSimplified) == "3 天")

        #expect(InitialScanScreen.formatDuration(95) == "1 min 35 sec")
        #expect(InitialScanScreen.formatDuration(95, language: .chineseSimplified) == "1 分 35 秒")
    }

    // MARK: - Helpers

    private static func stringsFileURL(lproj: String) -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<5 {
            let candidate = dir
                .appendingPathComponent("Sources/CairnIOSCore/Resources/\(lproj).lproj/Localizable.strings")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    private struct ParsedStrings {
        let entries: [String: String]
        let duplicates: Set<String>
    }

    private static func parseStringsFile(at url: URL) throws -> ParsedStrings {
        let raw = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(
            pattern: #"^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";$"#
        )
        var entries: [String: String] = [:]
        var duplicates: Set<String> = []
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\"") else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: range),
                  let keyRange = Range(match.range(at: 1), in: trimmed),
                  let valRange = Range(match.range(at: 2), in: trimmed) else {
                continue
            }
            let key = String(trimmed[keyRange])
            let val = String(trimmed[valRange])
            if entries[key] != nil {
                duplicates.insert(key)
            }
            entries[key] = val
        }
        return ParsedStrings(entries: entries, duplicates: duplicates)
    }

    private static func formatSpecifiers(in value: String) -> [String] {
        let stripped = value.replacingOccurrences(of: "%%", with: "")
        guard let regex = try? NSRegularExpression(pattern: #"%(\d+\$)?[0-9.]*[@dfsu]"#) else {
            return []
        }
        let range = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
        var specs: [(Int, String)] = []
        var positionalIndex = 1
        for match in regex.matches(in: stripped, range: range) {
            guard let fullRange = Range(match.range, in: stripped) else { continue }
            let token = String(stripped[fullRange])
            let typeChar = String(token.suffix(1))
            if let posRange = Range(match.range(at: 1), in: stripped) {
                let digits = String(stripped[posRange]).dropLast()
                let idx = Int(digits) ?? positionalIndex
                specs.append((idx, typeChar))
            } else {
                specs.append((positionalIndex, typeChar))
                positionalIndex += 1
            }
        }
        return specs.sorted { $0.0 < $1.0 }.map { "\($0.0):\($0.1)" }
    }
}
