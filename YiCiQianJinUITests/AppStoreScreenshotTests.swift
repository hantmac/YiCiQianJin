import XCTest

/// Generates App Store screenshots on whichever display the simulator is showing
/// (iPhone Duo outer when closed, inner when open). Run with TEST_RUNNER_SCREENSHOT_DIR set.
final class AppStoreScreenshotTests: XCTestCase {
    /// The first 42 CET-4 words with their real meanings; word #43 ("harbour") is today's word.
    private let learned: [(String, String)] = [
        ("cancel", "取消， 撤销； 删去"),
        ("explosive", "爆炸的； 极易引起争论的；炸药"),
        ("numerous", "众多的"),
        ("gratitude", "感激， 感谢， 感恩"),
        ("analyse", "分析； 分解； 解析"),
        ("discourage", "使泄气， 使灰心； 阻止， 劝阻"),
        ("resemble", "像， 类似于"),
        ("remote", "遥远的； 偏僻的； 关系疏远的； 脱离的； 微乎其微的； 孤高的， 冷淡的； 遥控的"),
        ("salary", "薪金， 薪水"),
        ("pollution", "污染， 污染物"),
        ("pretend", "装作， 假装"),
        ("kettle", "水壶"),
        ("wreck", "失事；残骸；精神或身体已垮的人；破坏"),
        ("drunk", "醉的； 陶醉的"),
        ("colleague", "同事， 同僚"),
        ("persistent", "坚持的， 不屈不挠的； 持续不断的； 反复出现的"),
        ("sake", "缘故， 理由"),
        ("conceal", "把…隐藏起来， 掩盖， 隐瞒"),
        ("audience", "听众， 观众， 读者"),
        ("meanwhile", "与此同时"),
        ("possess", "占用， 拥有"),
        ("competent", "有能力的， 能胜任的"),
        ("investment", "投资， 投资额； 投入"),
        ("neutral", "中立的； 中性的"),
        ("scratch", "抓，搔，扒；刮，擦；刻出；抓痕， 划痕； 抓， 搔， 刮"),
        ("optional", "可以任选的"),
        ("require", "需要； 要求； 命令"),
        ("circular", "圆的；循环的；兜圈子的；通知， 通告"),
        ("analysis", "分析， 分析报告； 分解； 解析"),
        ("click", "发出咔嗒声；点击；咔嗒声"),
        ("fashionable", "流行的， 时髦的"),
        ("therapy", "治疗， 理疗"),
        ("apparent", "表面上的， 明显的"),
        ("journalist", "新闻工作者， 新闻记者"),
        ("encounter", "遭遇，遇到；遭遇"),
        ("temper", "韧度；心情，情绪；调和， 使缓和； 【冶】使回火"),
        ("protective", "保护的， 防护的"),
        ("sideways", "从一边， 向一边； 在一边； 斜着， 侧身"),
        ("philosopher", "哲学家， 哲人"),
        ("object", "反对， 不赞成；实物， 物体； 目的， 目标； 对象， 客体； 宾语"),
        ("humble", "谦逊的； 地位低下的； 简陋的"),
        ("chapter", "章， 回， 篇")
    ]

    override func setUp() {
        continueAfterFailure = false
    }

    // Every seeded word has a Word Atlas illustration so the forced picture question always applies.
    private func seedState() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let today = f.string(from: Date())
        func day(_ back: Int) -> String { f.string(from: cal.date(byAdding: .day, value: -back, to: Date())!) }
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "\"", with: "") }

        var records: [String] = []
        var results: [String] = []
        var review: [String] = []
        for (i, (word, meaning)) in learned.enumerated() {
            let back = learned.count - i            // one word per day, ending yesterday
            records.append(#"{"date":"\#(day(back))","word":"\#(word)","meaning":"\#(esc(meaning))","bookId":"cet4","passed":true}"#)
            // Next-day exam: a few misses to populate the mistakes notebook.
            let correct = ![5, 12, 19, 27].contains(i)
            results.append(#"{"word":"\#(word)","correct":\#(correct),"date":"\#(day(back - 1))","source":"exam","bookId":"cet4"}"#)
            if i < 12 {
                review.append(#""cet4|\#(word)":{"stage":\#(4 + i % 2),"due":"\#(day(-(10 + i)))"}"#)
            } else if i < 24 {
                review.append(#""cet4|\#(word)":{"stage":2,"due":"\#(day(-(2 + i % 3)))"}"#)
            }
        }
        return #"{"selectedBookId":"cet4","isPremium":false,"currentWordIndex":\#(learned.count),"studyRecords":[\#(records.joined(separator: ","))],"todayStudied":false,"todayQuizPassed":true,"todayDate":"\#(today)","quizResults":[\#(results.joined(separator: ","))],"reviewStates":{\#(review.joined(separator: ","))},"autoPronounce":false}"#
    }

    private func snap(_ name: String) {
        ScreenCapture.save(ScreenCapture.active(), name: name, in: self)
    }

    private func tapButton(_ app: XCUIApplication, beginsWith prefix: String) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        // Short displays (iPhone Duo outer) may need scrolling before the button exists/is hittable.
        var swipes = 0
        while !(button.exists && button.isHittable) && swipes < 6 {
            if button.waitForExistence(timeout: 1) && button.isHittable { break }
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(button.exists && button.isHittable, "button \(prefix) not found")
        button.tap()
    }

    func testCaptureAppStoreScreens() {
        let app = XCUIApplication()
        let hex = Data(seedState().utf8).map { String(format: "%02x", $0) }.joined()
        app.launchArguments = ["-yiciqianjin_state", "<\(hex)>", "-UITestQuizKind", "picture",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        // TEST_RUNNER_SCREENSHOT_ORIENTATION=landscape captures the two-pane layout (iPad / Duo inner).
        if ProcessInfo.processInfo.environment["SCREENSHOT_ORIENTATION"] == "landscape" {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }

        tapButton(app, beginsWith: "开始学习")
        tapButton(app, beginsWith: "揭晓释义")
        XCTAssertTrue(app.staticTexts["studyWord"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["studyWord"].label, "harbour")
        sleep(2)
        snap("1-study")

        tapButton(app, beginsWith: "收入词库")
        let collect = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '收下千金'")).firstMatch
        XCTAssertTrue(collect.waitForExistence(timeout: 5))
        sleep(2)
        snap("5-check-in")
        // Due words exist, so the check-in continues straight into review.
        collect.tap()

        XCTAssertTrue(app.staticTexts["看图，选出画的是哪个单词"].waitForExistence(timeout: 5))
        sleep(2)
        snap("2-picture-quiz")
        app.buttons["退出温故复习"].tap()

        XCTAssertTrue(app.staticTexts["今日学习"].waitForExistence(timeout: 5))
        sleep(1)
        snap("3-home")

        app.tabBars.buttons["词库"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["词库"].waitForExistence(timeout: 5))
        sleep(2)
        snap("4-library")
    }
}
