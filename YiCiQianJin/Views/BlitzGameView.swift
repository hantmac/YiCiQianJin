import SwiftUI

/// 60 秒闪电战: rapid four-choice questions on learned words against the clock.
struct BlitzGameView: View {
    @Bindable var vm: StudyViewModel
    @State private var session = 0

    var body: some View {
        BlitzSession(vm: vm, onReplay: { session += 1 })
            .id(session)
            .navigationTitle(GameKind.blitz.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { vm.go(.discover) } label: {
                        Label("退出闪电战", systemImage: "xmark")
                    }
                }
            }
    }
}

private struct BlitzSession: View {
    let vm: StudyViewModel
    let onReplay: () -> Void

    private enum Phase { case countdown(Int), playing, over }

    private struct FloatText: Identifiable, Equatable {
        enum Place { case score, timer }
        let id = UUID()
        let text: String
        let tint: Color
        let place: Place
    }

    @State private var phase: Phase = .countdown(3)
    @State private var pool: [StudyRecord] = []
    @State private var question: QuizQuestion?
    @State private var asked = 0
    @State private var deadline = Date()
    @State private var feverUntil: Date?
    @State private var selected: String?
    @State private var score = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var correct = 0
    @State private var answered = 0
    @State private var missed: [StudyRecord] = []
    @State private var floats: [FloatText] = []
    @State private var lastTick = -1
    @State private var coins = 0
    @State private var isRecord = false
    @State private var shake: CGFloat = 0
    @State private var hapticCorrect = 0
    @State private var hapticWrong = 0
    @State private var hapticFever = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Cleared by a timer when the 5 seconds are up, so views update without polling.
    private var inFever: Bool { feverUntil != nil }

    var body: some View {
        ZStack {
            feverGlow
            Group {
                switch phase {
                case .countdown(let n):
                    countdown(n)
                case .playing:
                    playing
                case .over:
                    GameSummaryView(
                        vm: vm,
                        title: "闪电战结束",
                        badge: .rank(GameRules.blitzRank(score: score)),
                        value: "\(score)",
                        unit: "分",
                        isRecord: isRecord,
                        stats: [("答对", "\(correct)/\(answered)"), ("最高连对", "\(bestCombo)")],
                        coins: coins,
                        missed: missed.uniqueWords(),
                        onReplay: onReplay,
                        onExit: { vm.finishGame() })
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: hapticCorrect)
        .sensoryFeedback(.error, trigger: hapticWrong)
        .sensoryFeedback(.success, trigger: hapticFever)
        .task {
            pool = vm.learnedWords
            GameSound.shared.prepareIfNeeded()
            for n in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(n)
                GameSound.shared.play(.tick)
                try? await Task.sleep(for: .seconds(0.7))
                if Task.isCancelled { return }
            }
            start()
        }
    }

    // MARK: - Fever glow

    /// 金色时刻: the whole scene warms up while points are doubled.
    private var feverGlow: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !inFever)) { context in
            let active = inFever
            ZStack {
                RadialGradient(colors: [Theme.gold.opacity(0.32), .clear], center: .top, startRadius: 0, endRadius: 520)
                RadialGradient(colors: [Theme.goldDeep.opacity(0.2), .clear], center: .bottom, startRadius: 0, endRadius: 420)
            }
            .opacity(active ? (reduceMotion ? 1 : 0.75 + 0.25 * sin(context.date.timeIntervalSinceReferenceDate * 6)) : 0)
            .animation(.easeInOut(duration: 0.4), value: active)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Countdown

    private func countdown(_ n: Int) -> some View {
        VStack(spacing: 14) {
            Text("\(n)")
                .font(.system(size: 96, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.gold)
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(duration: 0.3), value: n)
            Text("连对 \(GameRules.blitzBonusEvery) 题 +\(GameRules.blitzBonusSeconds) 秒，连对 \(GameRules.feverEvery) 题进入金色时刻")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: 18) {
            hud
            if let question {
                // The card takes the free height; options stay low, within thumb reach.
                VStack(spacing: 18) {
                    stimulus(question)
                        .modifier(Shake(animatableData: shake))
                    options(question)
                }
                .id(question.id)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .readableWidth(560)
        .task {
            // Polling keeps penalties and bonuses (which move the deadline) simple.
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                if left <= 0 { finish(); return }
                let whole = Int(left.rounded(.up))
                if whole <= 5 && whole != lastTick {
                    lastTick = whole
                    GameSound.shared.play(.tick)
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private var hud: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("分")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .overlay(alignment: .topLeading) { floatLayer(.score).offset(x: 70) }
                Spacer()
                comboChip
                Spacer()
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    let left = max(0, deadline.timeIntervalSince(context.date))
                    Text(String(format: "%.0f", left.rounded(.up)))
                        .font(.system(size: 34, weight: .semibold, design: .serif).monospacedDigit())
                        .foregroundStyle(left <= 10 ? Theme.wrong : Theme.textPrimary)
                        .frame(minWidth: 56, alignment: .trailing)
                        .accessibilityLabel("剩余 \(Int(left.rounded(.up))) 秒")
                }
                .overlay(alignment: .topTrailing) { floatLayer(.timer).offset(x: -64) }
            }
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let left = max(0, deadline.timeIntervalSince(context.date))
                let tint: AnyShapeStyle = left <= 10 ? AnyShapeStyle(Theme.wrong) : AnyShapeStyle(Theme.goldGradient)
                CapsuleBar(progress: left / Double(GameRules.blitzSeconds), height: 6, tint: tint)
            }
        }
    }

    /// Flame + combo, with the multiplier during 金色时刻.
    @ViewBuilder
    private var comboChip: some View {
        if combo >= 2 || inFever {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text(inFever ? "金色时刻 ×2" : "\(combo) 连对")
                    .contentTransition(.numericText())
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.onGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.goldGradient, in: Capsule())
            .scaleEffect(inFever && !reduceMotion ? 1.12 : 1)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(duration: 0.3, bounce: 0.5), value: combo)
            .accessibilityLabel(inFever ? "金色时刻，双倍得分" : "连对 \(combo) 题")
        }
    }

    private func floatLayer(_ place: FloatText.Place) -> some View {
        ZStack {
            ForEach(floats.filter { $0.place == place }) { f in
                Text(f.text)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(f.tint)
                    .fixedSize()
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .offset(y: 10).combined(with: .opacity),
                        removal: .offset(y: -16).combined(with: .opacity)))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stimulus(_ q: QuizQuestion) -> some View {
        VStack(spacing: 10) {
            Text(prompt(q))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            switch q.kind {
            case .picture:
                WordIllustration(word: q.record.word, cornerRadius: 18, maxPixel: 420)
                    .frame(width: 150, height: 150)
            case .listen:
                Button { Pronouncer.shared.speak(q.record.word) } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.onGold)
                        .frame(width: 84, height: 84)
                        .background(Theme.goldGradient, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("再听一遍")
            case .chooseMeaning:
                Text(q.record.word)
                    .font(Theme.wordFont(40))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            default:
                Text(GameRules.shortMeaning(q.record.meaning))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 420)
        .frame(maxHeight: .infinity)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(inFever ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.stroke), lineWidth: inFever ? 1.5 : 1))
    }

    private func prompt(_ q: QuizQuestion) -> String {
        switch q.kind {
        case .chooseMeaning: return "选出正确的意思"
        case .picture: return "画的是哪个词？"
        case .listen: return "听发音，选出单词"
        default: return "哪个单词是这个意思？"
        }
    }

    private func options(_ q: QuizQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(q.options, id: \.self) { option in
                let isAnswer = option == q.answer
                let state: Color? = selected == nil ? nil : (isAnswer ? Theme.correct : (option == selected ? Theme.wrong : nil))
                let text = q.kind == .chooseMeaning ? GameRules.shortMeaning(option) : option
                Button { answer(option, q) } label: {
                    Text(text)
                        .font(q.kind == .chooseMeaning ? .subheadline.weight(.semibold) : Theme.wordFont(19))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background((state ?? .clear).opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(state ?? Theme.stroke, lineWidth: state == nil ? 1 : 1.5))
                        .scaleEffect(selected == option && isAnswer && !reduceMotion ? 1.05 : 1)
                }
                .buttonStyle(PressableStyle())
                .disabled(selected != nil)
                .accessibilityLabel(text)
            }
        }
    }

    // MARK: - Flow

    private func start() {
        var seconds = GameRules.blitzSeconds
        #if DEBUG
        // UI tests reach the summary quickly: -UITestBlitzSeconds 12
        let forced = UserDefaults.standard.integer(forKey: "UITestBlitzSeconds")
        if forced > 0 { seconds = forced }
        #endif
        deadline = Date().addingTimeInterval(TimeInterval(seconds))
        nextQuestion()
        withAnimation(.easeOut(duration: 0.25)) { phase = .playing }
    }

    /// Text questions to warm up, then pictures and listening join the mix.
    private func nextQuestion() {
        let candidates = pool.count > 1 ? pool.filter { $0.wordKey != question?.record.wordKey } : pool
        guard let record = candidates.randomElement() else { return }
        var kinds: [QuestionKind] = [.chooseMeaning, .chooseWord]
        if asked >= GameRules.blitzWarmup {
            kinds.append(.listen)
            if WordAtlas.hasImage(record.word) { kinds += [.picture, .picture] }
        }
        let kind = kinds.randomElement()!
        selected = nil
        asked += 1
        question = QuestionFactory.make(for: record, pool: WordData.pool(for: record), kind: kind)
        if question?.kind == .listen { Pronouncer.shared.speak(record.word) }
    }

    private func answer(_ option: String, _ q: QuizQuestion) {
        guard selected == nil, case .playing = phase else { return }
        let isCorrect = option == q.answer
        selected = option
        answered += 1

        withAnimation(.spring(duration: 0.3)) {
            if isCorrect {
                combo += 1
                bestCombo = max(bestCombo, combo)
                correct += 1
                let points = GameRules.blitzPoints(combo: combo) * (inFever ? 2 : 1)
                score += points
                pop("+\(points)", tint: Theme.gold, at: .score)
                GameSound.shared.correct(combo: combo)
                hapticCorrect += 1

                if combo % GameRules.feverEvery == 0 {
                    let until = Date().addingTimeInterval(GameRules.feverSeconds)
                    feverUntil = until
                    GameSound.shared.play(.fever)
                    hapticFever += 1
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(GameRules.feverSeconds))
                        if feverUntil == until { withAnimation(.easeOut(duration: 0.4)) { feverUntil = nil } }
                    }
                } else if combo % GameRules.blitzBonusEvery == 0 {
                    deadline = deadline.addingTimeInterval(TimeInterval(GameRules.blitzBonusSeconds))
                    lastTick = -1
                    pop("+\(GameRules.blitzBonusSeconds) 秒", tint: Theme.correct, at: .timer)
                    GameSound.shared.play(.bonus)
                }
            } else {
                combo = 0
                feverUntil = nil
                missed.append(q.record)
                deadline = deadline.addingTimeInterval(-TimeInterval(GameRules.blitzPenalty))
                pop("-\(GameRules.blitzPenalty) 秒", tint: Theme.wrong, at: .timer)
                GameSound.shared.play(.wrong)
                hapticWrong += 1
            }
        }
        if !isCorrect { withAnimation(.default) { shake += 1 } }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(isCorrect ? 280 : 700))
            guard case .playing = phase else { return }
            withAnimation(.spring(duration: 0.3)) { nextQuestion() }
        }
    }

    private func pop(_ text: String, tint: Color, at place: FloatText.Place) {
        let f = FloatText(text: text, tint: tint, place: place)
        floats.append(f)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.3)) { floats.removeAll { $0.id == f.id } }
        }
    }

    private func finish() {
        guard case .playing = phase else { return }
        let previous = GameRules.best(.blitz, in: vm.state.gameRecords)
        isRecord = score > 0 && score > (previous ?? 0)
        coins = vm.recordGame(.blitz, score: score, correct: correct, total: answered)
        feverUntil = nil
        withAnimation(.easeInOut(duration: 0.3)) { phase = .over }
    }
}
