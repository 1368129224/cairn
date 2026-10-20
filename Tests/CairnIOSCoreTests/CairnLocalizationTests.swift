import Testing
import CairnCore
@testable import CairnIOSCore

@Suite("Localization startup regression", .serialized)
struct CairnLocalizationTests {
    @Test("Chinese lookup initializes the dictionary without trapping; language switching preserves fallback")
    func dictionaryInitializationAndLanguageSwitching() {
        let originalLanguage = CairnL10n.currentLanguage
        defer { CairnL10n.currentLanguage = originalLanguage }

        // A duplicate dictionary-literal key traps on the first Chinese lookup,
        // not during compilation. Exercise the same path used by app startup.
        CairnL10n.currentLanguage = .chineseSimplified
        #expect(CairnL10n.text("Status") == "状态")
        #expect(CairnL10n.text("Backlog alert") == "待删积压提醒")
        #expect(CairnL10n.text("QUICK SETTINGS") == "快捷设置")
        #expect(CairnL10n.text("Indexing your library") == "索引照片库")
        #expect(CairnL10n.text("processed") == "已处理")
        #expect(CairnL10n.text("ELAPSED") == "已耗时")
        #expect(CairnL10n.text("REMAINING") == "预估剩余")
        #expect(CairnL10n.text("Start indexing") == "开始索引")
        #expect(CairnL10n.text("Resume indexing") == "继续索引")
        #expect(CairnL10n.text("Scan options") == "扫描选项")
        #expect(CairnL10n.text("Sync detail") == "同步详情")
        #expect(CairnL10n.text("Deferred queue") == "推迟处理队列")
        #expect(CairnL10n.text("Clear hash cache?") == "清空哈希缓存？")
        #expect(CairnL10n.text("Rescan library?") == "重新扫描照片库？")
        #expect(CairnL10n.text("Reset index?") == "重置索引？")
        #expect(CairnL10n.text("Disconnect server?") == "断开服务器连接？")
        #expect(CairnL10n.text("Find missed deletions") == "查找遗漏的删除")
        #expect(CairnL10n.text("Archived history") == "归档历史")
        #expect(CairnL10n.text("unknown-localization-key") == "unknown-localization-key")

        CairnL10n.currentLanguage = .english
        #expect(CairnL10n.text("Status") == "Status")
        #expect(CairnL10n.text("Backlog alert") == "Backlog alert")

        CairnL10n.currentLanguage = .chineseSimplified
        #expect(CairnL10n.text("Status") == "状态")
    }
}
