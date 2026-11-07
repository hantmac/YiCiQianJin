import SwiftUI

/// Question session used for both the daily exam (yesterday's words) and spaced review.
struct QuizView: View {
    enum Mode {
        case exam, review

        var title: String { self == .exam ? "昨日考试" : "温故复习" }
        var source: QuizSource { self == .exam ? .exam : .review }
        var reward: Int { self == .exam ? LearningStats.Reward.examCorrect : LearningStats.Reward.reviewCorrect }
    }

    @Bindable var vm: StudyViewModel
    let mode: Mode

    /// Snapshot taken when the session starts; answering changes the due list, the session must not.
    @State private var questions: [QuizQuestion]
    @State private var index = 0
    @State private var answered = false
    @State private var lastCorrect = false
    @State private var selectedOption: String?
    @State private var input = ""
    @State private var usedTiles: [Int] = []
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var correctCount = 0
    @State private var failed: [StudyRecord] = []
    @State private var showSummary = false
    @State private var feedbackTick = 0
    /// Schedule before the current answer, so "有点模糊" can regrade it.
    @State private var previousState: ReviewState?
    @State private var usedHint = false
    @FocusState private var inputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(vm: StudyViewModel, mode: Mode, records: [StudyRecord]) {
        self.vm = vm
        self.mode = mode
        #if DEBUG
        // UI tests / App Store screenshots can pin the question type: -UITestQuizKind picture
        let forced = UserDefaults.standard.string(forKey: "UITestQuizKind").flatMap(QuestionKind.init(rawValue:))
        #else
        let forced: QuestionKind? = nil
        #endif
        _questions = State(initialValue: records.shuffled().map {
            QuestionFactory.make(for: $0, pool: WordData.pool(for: $0), kind: forced)
        })
    }

    private var question: QuizQuestion? { questions.indices.contains(index) ? questions[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            if showSummary || question == nil {
                summary
            } else if let question {
                header
                AdaptiveSplit {
                    ScrollView {
                        stimulusSection(question, pictureSide: 460)
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                } secondary: {
                    VStack(spacing: 0) {
                        ScrollView {
                            answerSection(question)
                                .padding(.horizontal)
                                .padding(.top, 18)
                                .padding(.bottom, 24)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollIndicators(.hidden)
                        footer(question)
                    }
                } compact: {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 18) {
                                stimulusSection(question, pictureSide: 280)
                                answerSection(question)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                            .readableWidth()
                        }
                        .scrollDismissesKeyboard(.interactively)
                        footer(question).readableWidth()
                    }
                }
                .id(question.id)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
                .task(id: question.id) { questionAppeared(question) }
            }
        }
        .navigationTitle(showSummary ? "" : mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !showSummary {
                ToolbarItem(placement: .cancellationAction) {
                    Button { vm.go(.home) } label: {
                        Label("退出\(mode.title)", systemImage: "xmark")
                    }
                }
            }
        }
        .sensoryFeedback(trigger: feedbackTick) { _, _ in lastCorrect ? .success : .error }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                CapsuleBar(progress: Double(index + (answered ? 1 : 0)) / Double(max(questions.count, 1)), height: 10)
                Text("\(index + 1)/\(questions.count)")
                    .font(Theme.number(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
            HStack {
                Spacer()
                if combo >= 2 {
                    Label("连对 ×\(combo)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.onGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.goldGradient, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.5), value: combo)
            .frame(minHeight: 24)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .readableWidth(900)
    }

    // MARK: - Question

    private func stimulusSection(_ q: QuizQuestion, pictureSide: CGFloat) -> some View {
        VStack(spacing: 18) {
            Text(q.kind.prompt)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 18)

            if q.kind == .picture {
                WordIllustration(word: q.record.word, cornerRadius: 26)
                    .frame(maxWidth: pictureSide)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            } else {
                stimulus(q)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.stroke))
            }
        }
    }

    @ViewBuilder
    private func answerSection(_ q: QuizQuestion) -> some View {
        VStack(spacing: 18) {
            switch q.kind {
            case .chooseMeaning, .chooseWord, .listen, .picture:
                options(q)
            case .fillLetters:
                tiles(q)
            case .spell:
                spellField(q)
            }

            if answered { feedback(q).transition(.scale(scale: 0.95).combined(with: .opacity)) }
        }
    }

    private func questionAppeared(_ q: QuizQuestion) {
        if q.kind == .listen || (q.kind == .chooseMeaning && vm.state.autoPronounce) {
            Pronouncer.shared.speak(q.record.word)
        }
        if q.kind == .spell { inputFocused = true }
    }

    @ViewBuilder
    private func stimulus(_ q: QuizQuestion) -> some View {
        switch q.kind {
        case .chooseMeaning:
            VStack(spacing: 12) {
                Text(q.record.word)
                    .font(Theme.wordFont(40))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                SpeakButton(text: q.record.word, size: 36)
            }
        case .listen:
            VStack(spacing: 12) {
                Button { Pronouncer.shared.speak(q.record.word) } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Theme.onGold)
                        .frame(width: 88, height: 88)
                        .background(Theme.goldGradient, in: Circle())
                        .shadow(color: Theme.goldDeep.opacity(0.4), radius: 14, y: 6)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("再听一遍")
                Button("慢速播放") { Pronouncer.shared.speak(q.record.word, slow: true) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        case .chooseWord, .spell:
            meaningText(q.record.meaning)
        case .picture:
            EmptyView() // rendered by stimulusSection
        case .fillLetters:
            VStack(spacing: 18) {
                meaningText(q.record.meaning)
                letterPattern(q)
            }
        }
    }

    private func meaningText(_ meaning: String) -> some View {
        Text(meaning)
            .font(.title2.weight(.bold))
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
    }

    // MARK: Options

    private func options(_ q: QuizQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                let state = optionState(option, q)
                Button {
                    guard !answered else { return }
                    selectedOption = option
                    submit(q, correct: option == q.answer)
                } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: String(UnicodeScalar(UInt8(65 + i))))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle((state == .correct || state == .wrong) ? Theme.onGold : Theme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(state.badge, in: Circle())
                        Text(option)
                            .font(q.kind == .chooseMeaning ? .body : Theme.wordFont(20))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if let icon = state.icon {
                            Image(systemName: icon).foregroundStyle(state.color)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 56)
                    .background(state.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(state.color.opacity(state == .idle ? 0 : 0.9), lineWidth: 1.5))
                    .opacity(state == .dimmed ? 0.5 : 1)
                }
                .buttonStyle(PressableStyle())
                .disabled(answered)
                .accessibilityLabel(option)
            }
        }
    }

    private enum OptionState {
        case idle, correct, wrong, dimmed

        var color: Color {
            switch self {
            case .correct: return Theme.correct
            case .wrong: return Theme.wrong
            default: return Theme.stroke
            }
        }
        var fill: Color {
            switch self {
            case .correct: return Theme.correct.opacity(0.18)
            case .wrong: return Theme.wrong.opacity(0.18)
            default: return Theme.surface
            }
        }
        var badge: Color {
            switch self {
            case .correct: return Theme.correct
            case .wrong: return Theme.wrong
            default: return Theme.surfaceStrong
            }
        }
        var icon: String? {
            switch self {
            case .correct: return "checkmark.circle.fill"
            case .wrong: return "xmark.circle.fill"
            default: return nil
            }
        }
    }

    private func optionState(_ option: String, _ q: QuizQuestion) -> OptionState {
        guard answered else { return .idle }
        if option == q.answer { return .correct }
        if option == selectedOption { return .wrong }
        return .dimmed
    }

    // MARK: Letter tiles

    private var filledLetters: [Character] {
        guard let q = question else { return [] }
        return usedTiles.compactMap { id in q.tiles.first { $0.id == id }?.letter }
    }

    private func letterPattern(_ q: QuizQuestion) -> some View {
        let filled = filledLetters
        var blankIndex = 0
        let cells: [(id: Int, text: String, isBlank: Bool, isFilled: Bool)] = q.pattern.enumerated().map { i, ch in
            if let ch { return (i, String(ch), false, false) }
            defer { blankIndex += 1 }
            let letter = blankIndex < filled.count ? String(filled[blankIndex]) : ""
            return (i, letter, true, !letter.isEmpty)
        }
        let color = answered ? (lastCorrect ? Theme.correct : Theme.wrong) : Theme.gold
        func cellView(_ cell: (id: Int, text: String, isBlank: Bool, isFilled: Bool), width: CGFloat) -> some View {
            Text(cell.text == " " ? "" : cell.text)
                .font(.system(size: width * 0.8, weight: .bold, design: .monospaced))
                .foregroundStyle(cell.isBlank ? color : Theme.textPrimary)
                .frame(width: cell.text == " " ? width * 0.4 : width, height: width * 1.45)
                .background {
                    if cell.isBlank {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(cell.isFilled ? Theme.gold.opacity(0.16) : Theme.surface)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: cell.isFilled ? [] : [4, 3]))
                    }
                }
        }
        // Keep the word on one line whenever possible, shrinking cells before wrapping.
        return ViewThatFits(in: .horizontal) {
            ForEach([30.0, 25.0, 20.0], id: \.self) { width in
                HStack(spacing: width > 22 ? 4 : 3) {
                    ForEach(cells, id: \.id) { cellView($0, width: width) }
                }
                .fixedSize()
            }
            FlowLayout(spacing: 3) {
                ForEach(cells, id: \.id) { cellView($0, width: 20) }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("单词：\(q.pattern.map { $0.map(String.init) ?? "空" }.joined(separator: " "))")
    }

    private func tiles(_ q: QuizQuestion) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(q.tiles) { tile in
                    let used = usedTiles.contains(tile.id)
                    Button {
                        tapTile(tile, q)
                    } label: {
                        Text(verbatim: String(tile.letter))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(used ? .clear : Theme.onGold)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(used ? AnyShapeStyle(Theme.surface) : AnyShapeStyle(Theme.goldGradient),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(used || answered)
                    .accessibilityLabel("字母 \(String(tile.letter))")
                }
            }
            if !answered {
                Button {
                    if !usedTiles.isEmpty { usedTiles.removeLast() }
                } label: {
                    Label("退格", systemImage: "delete.left")
                }
                .buttonStyle(GlassButtonStyle(height: 44))
                .disabled(usedTiles.isEmpty)
                .opacity(usedTiles.isEmpty ? 0.5 : 1)
            }
        }
    }

    private func tapTile(_ tile: LetterTile, _ q: QuizQuestion) {
        guard !answered, usedTiles.count < q.missing.count else { return }
        withAnimation(.spring(duration: 0.2)) { usedTiles.append(tile.id) }
        if usedTiles.count == q.missing.count {
            submit(q, correct: filledLetters.map { Character($0.lowercased()) } == q.missing)
        }
    }

    // MARK: Spelling

    private func spellField(_ q: QuizQuestion) -> some View {
        HStack(spacing: 10) {
            TextField("", text: $input, prompt: Text("输入英文单词").foregroundStyle(Theme.textTertiary))
                .focused($inputFocused)
                .font(.title3.weight(.semibold))
                .foregroundStyle(answered ? (lastCorrect ? Theme.correct : Theme.wrong) : Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { submitSpelling(q) }
                .disabled(answered)
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
            if !answered {
                Button("提示") {
                    // Reveal the next correct letter instead of the whole word.
                    let target = Array(q.answer)
                    let typed = Array(input)
                    var prefix = 0
                    while prefix < min(typed.count, target.count),
                          typed[prefix].lowercased() == target[prefix].lowercased() { prefix += 1 }
                    if prefix < target.count {
                        input = String(target[0...prefix])
                        usedHint = true
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 60, height: 54)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func submitSpelling(_ q: QuizQuestion) {
        guard !answered, !input.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        inputFocused = false
        submit(q, correct: AnswerMatcher.matches(input, q.answer))
    }

    // MARK: - Feedback

    private func feedback(_ q: QuizQuestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if WordAtlas.hasImage(q.record.word) && q.kind != .picture {
                WordThumbnail(word: q.record.word, size: 52)
            } else {
                Image(systemName: lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(lastCorrect ? Theme.correct : Theme.wrong)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lastCorrect ? feedbackPraise : "没关系，记住它")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(q.record.word) · \(q.record.meaning)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label("下次复习 · \(MemoryFormat.relative(vm.reviewState(for: q.record).dueAt, from: Date()))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: 0)
            SpeakButton(text: q.record.word, size: 34)
        }
        .card(padding: 14, fill: (lastCorrect ? Theme.correct : Theme.wrong).opacity(0.14))
    }

    private var feedbackPraise: String {
        let base = "答对了！+\(mode.reward) 金"
        return combo >= 3 ? "\(base) · 手感火热" : base
    }

    private func footer(_ q: QuizQuestion) -> some View {
        Group {
            if answered {
                HStack(spacing: 10) {
                    // Third grade between "remembered" and "forgot": the user decides.
                    if lastCorrect && !usedHint {
                        Button("有点模糊") { markFuzzy(q) }
                            .buttonStyle(GlassButtonStyle(height: 54))
                            .frame(maxWidth: 140)
                    }
                    Button(index < questions.count - 1 ? "下一题" : "查看结果", action: next)
                        .buttonStyle(GoldButtonStyle())
                }
            } else if q.kind == .spell {
                Button("确认答案") { submitSpelling(q) }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Flow

    private func submit(_ q: QuizQuestion, correct: Bool) {
        // A spelling finished with hints counts as fuzzy, not remembered.
        previousState = vm.recordAnswer(q.record, correct: correct, source: mode.source,
                                        grade: correct && usedHint ? .fuzzy : nil)
        lastCorrect = correct
        if correct {
            correctCount += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
        } else {
            combo = 0
            failed.append(q.record)
        }
        feedbackTick += 1
        withAnimation(.spring(duration: 0.35)) { answered = true }
        if vm.state.autoPronounce && q.kind != .chooseMeaning { Pronouncer.shared.speak(q.record.word) }
    }

    private func markFuzzy(_ q: QuizQuestion) {
        if let previousState { vm.regrade(q.record, from: previousState, grade: .fuzzy) }
        next()
    }

    private func next() {
        guard index < questions.count - 1 else {
            withAnimation(.spring(duration: 0.4)) { showSummary = true }
            return
        }
        withAnimation(.spring(duration: 0.35)) {
            index += 1
            answered = false
            selectedOption = nil
            input = ""
            usedTiles = []
            usedHint = false
            previousState = nil
        }
    }

    // MARK: - Summary

    private var earned: Int {
        let perfect = mode == .exam && failed.isEmpty && !questions.isEmpty
        return correctCount * mode.reward + (perfect ? LearningStats.Reward.perfectExam : 0)
    }

    private var summaryTitle: String {
        if failed.isEmpty { return mode == .exam ? "全对！金榜题名" : "全部记住了！" }
        let ratio = Double(correctCount) / Double(max(questions.count, 1))
        return ratio >= 0.6 ? "不错，还差一点点" : "别灰心，再记一遍"
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: Double(correctCount) / Double(max(questions.count, 1)), lineWidth: 12,
                                 tint: AnyShapeStyle(failed.isEmpty ? Theme.goldGradient : LinearGradient(colors: [Theme.correct, Theme.correct], startPoint: .top, endPoint: .bottom)))
                    VStack(spacing: 0) {
                        Text("\(correctCount)/\(questions.count)")
                            .font(Theme.number(.largeTitle))
                            .foregroundStyle(Theme.textPrimary)
                        Text("答对")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 150, height: 150)
                .padding(.top, 36)

                Text(summaryTitle)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 12) {
                    summaryStat(value: "+\(earned)", label: "获得千金", symbol: "yensign.circle.fill", tint: Theme.gold)
                    summaryStat(value: "\(bestCombo)", label: "最高连对", symbol: "flame.fill", tint: Theme.flame)
                }

                if !failed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("这些词再看一眼")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("它们退回了 2 个记忆节点，一天之内会再出现在复习里")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        ForEach(failed.uniqueWords()) { record in
                            HStack(spacing: 12) {
                                WordThumbnail(word: record.word, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.word)
                                        .font(Theme.wordFont(22))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(record.meaning)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                SpeakButton(text: record.word, size: 34)
                            }
                            .card(padding: 12, radius: 16)
                        }
                    }
                    .card()
                }

                Button(summaryAction, action: finish)
                    .buttonStyle(GoldButtonStyle())
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
    }

    private var summaryAction: String {
        switch mode {
        case .exam:
            let prefix = failed.isEmpty ? "" : "记住了，"
            // Mirrors StudyViewModel.continueFlow, which runs once the exam is marked done.
            let next = (vm.canLearnNewWord && !vm.hasStudiedToday) ? "学习今日新词"
                : (vm.dueReviews.isEmpty ? "回到首页" : "继续温故复习")
            return prefix + next
        case .review:
            return "完成复习"
        }
    }

    private func summaryStat(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value)
                .font(Theme.number(.title2))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14)
    }

    private func finish() {
        switch mode {
        case .exam: vm.finishExam()
        case .review: vm.finishReview()
        }
    }
}
