import XCTest

/// End-to-end walkthroughs of the main learning loop. Screenshots are written to
/// $SCREENSHOT_DIR when set (pass TEST_RUNNER_SCREENSHOT_DIR to xcodebuild).
final class LearningFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(state: String?) -> XCUIApplication {
        let app = XCUIApplication()
        // Values in the argument domain override the persisted state for this launch only.
        let json = state ?? "{}"
        let hex = Data(json.utf8).map { String(format: "%02x", $0) }.joined()
        app.launchArguments = ["-yiciqianjin_state", "<\(hex)>", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        return app
    }

    /// Legacy (v1.0) state: 12 consecutive days of cet4 words up to yesterday, nothing today.
    private func legacyPendingState(days: Int = 12) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let words = ["cancel", "explosive", "numerous", "govern", "analyse", "curriculum", "petroleum",
                     "concentrate", "sequence", "classify", "permanent", "plantation", "worthwhile", "abundant"]
        var records: [String] = []
        var results: [String] = []
        for back in stride(from: days, through: 1, by: -1) {
            let date = f.string(from: cal.date(byAdding: .day, value: -back, to: Date())!)
            let word = words[(days - back) % words.count]
            records.append(#"{"date":"\#(date)","word":"\#(word)","meaning":"\#(word) 的释义","bookId":"cet4","passed":true}"#)
            if back < days {
                let prev = words[(days - back - 1) % words.count]
                results.append(#"{"word":"\#(prev)","correct":\#(back % 4 != 0),"date":"\#(date)"}"#)
            }
        }
        let yesterday = f.string(from: cal.date(byAdding: .day, value: -1, to: Date())!)
        return #"{"selectedBookId":"cet4","isPremium":false,"currentWordIndex":\#(days),"studyRecords":[\#(records.joined(separator: ","))],"todayStudied":false,"todayQuizPassed":false,"todayDate":"\#(yesterday)","quizResults":[\#(results.joined(separator: ","))]}"#
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        ScreenCapture.save(ScreenCapture.active(), name: name, in: self)
    }

    private func tap(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 5) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "button \(label) not found")
        button.tap()
    }

    /// Answers the current question with whatever input it needs (correctness doesn't matter).
    private func answerCurrentQuestion(_ app: XCUIApplication) {
        if app.buttons["确认答案"].waitForExistence(timeout: 1) {
            let field = app.textFields.firstMatch
            field.tap()
            field.typeText("zzz")
            app.buttons["确认答案"].tap()
            return
        }
        let tiles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '字母 '"))
        if tiles.count > 0 {
            var guardCount = 0
            while !app.buttons["查看结果"].exists && !app.buttons["下一题"].exists && guardCount < 10 {
                let enabled = tiles.allElementsBoundByIndex.first { $0.isEnabled && $0.isHittable }
                enabled?.tap()
                guardCount += 1
            }
            return
        }
        // Option questions: options are the buttons labelled with the choice text; pick the first hittable one.
        let header = ["退出昨日考试", "退出温故复习", "再听一遍", "慢速播放"]
        let option = app.buttons.allElementsBoundByIndex.first { el in
            el.isHittable && !header.contains(el.label) && !el.label.hasPrefix("朗读")
        }
        option?.tap()
    }

    // MARK: - Tests

    func testFirstLaunchLearnsFirstWordAndChecksIn() {
        let app = launch(state: nil)
        XCTAssertTrue(app.staticTexts["小象单词"].waitForExistence(timeout: 5))
        snap(app, "01-book-select-first-launch")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '四级词汇'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["开始今日学习"].waitForExistence(timeout: 5))
        snap(app, "02-home-new-user")

        tap(app, "开始今日学习")
        XCTAssertTrue(app.buttons["揭晓释义"].waitForExistence(timeout: 5))
        snap(app, "03-study-recall")

        tap(app, "揭晓释义")
        let word = app.staticTexts["studyWord"].label
        XCTAssertFalse(word.isEmpty)
        let field = app.textFields["spellField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        sleep(1)
        snap(app, "04-study-spelling-blurred")
        field.typeText(word)
        tap(app, "检查")
        XCTAssertTrue(app.staticTexts["默写正确，记住啦！"].waitForExistence(timeout: 3))
        snap(app, "05-study-spelled")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '收入词库'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["收下千金"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "06-check-in")

        // Nothing is due yet (the new word's first review is in 5 minutes), so the flow ends at home.
        tap(app, "收下千金")
        XCTAssertTrue(app.staticTexts["今天学完了"].waitForExistence(timeout: 5))
        snap(app, "07-home-done")
        // Free users can't start another new word today.
        XCTAssertFalse(app.buttons["开始今日学习"].exists)
    }

    func testLegacyUserTakesExamThenLearns() {
        let app = launch(state: legacyPendingState())
        XCTAssertTrue(app.buttons["开始学习"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["连续学习 12 天"].exists, "legacy streak should survive migration")
        snap(app, "10-home-exam-pending")

        // One button runs the whole day: exam → new word → review.
        tap(app, "开始学习")
        sleep(1)
        snap(app, "11-exam-question")
        answerCurrentQuestion(app)
        XCTAssertTrue(app.buttons["查看结果"].waitForExistence(timeout: 5))
        snap(app, "12-exam-feedback")

        tap(app, "查看结果")
        let toStudy = app.buttons.matching(NSPredicate(format: "label ENDSWITH '学习今日新词'")).firstMatch
        XCTAssertTrue(toStudy.waitForExistence(timeout: 5))
        snap(app, "13-exam-summary")

        toStudy.tap()
        XCTAssertTrue(app.buttons["揭晓释义"].waitForExistence(timeout: 5), "exam completion should unlock today's word")
        tap(app, "揭晓释义")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '收入词库'")).firstMatch.tap()
        // Older words are due, so the check-in hands over to review.
        tap(app, "收下千金，去复习")
        XCTAssertTrue(app.buttons["退出温故复习"].waitForExistence(timeout: 5))
        snap(app, "14-flow-review")
    }

    func testReviewSessionAndSecondaryPages() {
        let app = launch(state: legacyPendingState())
        XCTAssertTrue(app.buttons["开始学习"].waitForExistence(timeout: 5))

        // Review is also reachable from the library while the exam is pending.
        openTab(app, "词库")
        tap(app, "去复习")
        XCTAssertTrue(app.buttons["退出温故复习"].waitForExistence(timeout: 5))
        answerCurrentQuestion(app)
        XCTAssertTrue(app.buttons["下一题"].waitForExistence(timeout: 5))
        snap(app, "20-review-feedback")
        tap(app, "退出温故复习")

        openTab(app, "词库")
        XCTAssertTrue(app.staticTexts["词库"].waitForExistence(timeout: 5))
        snap(app, "21-library")
        tap(app, "易错词")
        snap(app, "22-library-mistakes")

        openTab(app, "我的")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '等级与成就'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["等级与成就"].waitForExistence(timeout: 5))
        snap(app, "23-achievements")
        app.swipeUp()
        snap(app, "24-achievements-badges")
        tap(app, "返回")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '学习日历'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["学习日历"].waitForExistence(timeout: 5))
        snap(app, "25-calendar")
        tap(app, "返回")

        tapPrefix(app, "设置")
        XCTAssertTrue(app.staticTexts["学习提醒"].waitForExistence(timeout: 5))
        snap(app, "26-settings")
        tap(app, "返回")

        tapPrefix(app, "更换词书")
        XCTAssertTrue(app.staticTexts["选择词书"].waitForExistence(timeout: 5))
        snap(app, "27-book-select")
    }

    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name].firstMatch
        let button = tab.waitForExistence(timeout: 3) ? tab : app.buttons[name].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3), "tab \(name) not found")
        button.tap()
    }

    private func tapPrefix(_ app: XCUIApplication, _ prefix: String) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        var swipes = 0
        while !(button.exists && button.isHittable) && swipes < 4 {
            if button.waitForExistence(timeout: 1) && button.isHittable { break }
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(button.exists, "button \(prefix) not found")
        button.tap()
    }

    func testMemoryCollectionAndGames() {
        let app = launch(state: legacyPendingState())
        XCTAssertTrue(app.buttons["开始学习"].waitForExistence(timeout: 5))
        openTab(app, "发现")
        snap(app, "29-discover")

        // Legacy schedules migrate onto the Ebbinghaus nodes and show up on the curve page.
        tapPrefix(app, "记忆曲线")
        XCTAssertTrue(app.staticTexts["为什么要按时复习"].waitForExistence(timeout: 5))
        snap(app, "30-memory")
        app.swipeUp()
        let weak = app.buttons.matching(NSPredicate(format: "label CONTAINS '记忆保持率'")).firstMatch
        if weak.waitForExistence(timeout: 3) {
            weak.tap()
            XCTAssertTrue(app.staticTexts["复习节点"].waitForExistence(timeout: 5))
            snap(app, "31-word-memory")
            tap(app, "完成")
        }
        tap(app, "返回")

        tapPrefix(app, "插画图鉴")
        XCTAssertTrue(app.staticTexts["插画图鉴"].waitForExistence(timeout: 5))
        snap(app, "32-collection")
        tap(app, "返回")
        app.swipeUp()

        tapPrefix(app, "60 秒闪电战")
        XCTAssertTrue(app.buttons["退出闪电战"].waitForExistence(timeout: 5))
        sleep(3) // 3-2-1 countdown
        snap(app, "33-blitz")
        tap(app, "退出闪电战")

        tapPrefix(app, "词义配对")
        XCTAssertTrue(app.staticTexts["先点单词，再点它的意思"].waitForExistence(timeout: 5))
        snap(app, "34-match")
        tap(app, "退出词义配对")
        XCTAssertTrue(app.staticTexts["小游戏"].waitForExistence(timeout: 5), "games return to the discover tab")
    }
}
