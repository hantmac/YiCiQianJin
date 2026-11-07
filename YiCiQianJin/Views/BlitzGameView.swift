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
                    Button { vm.go(.games) } label: {
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

    @State private var phase: Phase = .countdown(3)
    @State private var pool: [StudyRecord] = []
    @State private var question: QuizQuestion?
    @State private var deadline = Date()
    @State private var selected: String?
    @State private var score = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var correct = 0
    @State private var answered = 0
    @State private var missed: [StudyRecord] = []
    @State private var lastGain: Gain?
    @State private var feedbackTick = 0
    @State private var lastCorrect = false
    @State private var coins = 0
    @State private var isRecord = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Gain: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let positive: Bool
    }

    var body: some View {
        Group {
            switch phase {
            case .countdown(let n):
                countdown(n)
            case .playing:
                playing
            case .over:
                GameSummaryView(
                    title: "闪电战结束",
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(trigger: feedbackTick) { _, _ in lastCorrect ? .impact(weight: .light) : .error }
        .task {
            pool = vm.learnedWords
            for n in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(n)
                try? await Task.sleep(for: .seconds(0.7))
                if Task.isCancelled { return }
            }
            start()
        }
    }

    // MARK: - Countdown

    private func countdown(_ n: Int) -> some View {
        VStack(spacing: 14) {
            Text("\(n)")
                .font(.system(size: 96, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.gold)
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(duration: 0.3), value: n)
            Text("看词选义、看义选词，越快越好")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: 18) {
            hud
            if let question {
                // Options sit low, within thumb reach.
                VStack(spacing: 18) {
                    Spacer(minLength: 0)
                    stimulus(question)
                    Spacer(minLength: 0)
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
            // The round ends on its own; polling keeps penalties (which move the deadline) simple.
            while !Task.isCancelled {
                if Date() >= deadline { finish(); return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private var hud: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("分")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .overlay(alignment: .topTrailing) {
                    if let gain = lastGain {
                        Text(gain.text)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(gain.positive ? Theme.gold : Theme.wrong)
                            .offset(x: 44, y: -2)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .id(gain.id)
                    }
                }
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
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    let left = max(0, deadline.timeIntervalSince(context.date))
                    Text(String(format: "%.0f", left.rounded(.up)))
                        .font(.system(size: 34, weight: .semibold, design: .serif).monospacedDigit())
                        .foregroundStyle(left <= 10 ? Theme.wrong : Theme.textPrimary)
                        .frame(minWidth: 56, alignment: .trailing)
                        .accessibilityLabel("剩余 \(Int(left.rounded(.up))) 秒")
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.5), value: combo)
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let left = max(0, deadline.timeIntervalSince(context.date))
                CapsuleBar(progress: left / Double(GameRules.blitzSeconds), height: 6,
                           tint: AnyShapeStyle(left <= 10 ? AnyShapeStyle(Theme.wrong) : AnyShapeStyle(Theme.goldGradient)))
            }
        }
    }

    @ViewBuilder
    private func stimulus(_ q: QuizQuestion) -> some View {
        VStack(spacing: 8) {
            Text(q.kind == .chooseMeaning ? "选出正确的意思" : "哪个单词是这个意思？")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Group {
                if q.kind == .chooseMeaning {
                    Text(q.record.word)
                        .font(Theme.wordFont(40))
                        .minimumScaleFactor(0.5)
                } else {
                    Text(GameRules.shortMeaning(q.record.meaning))
                        .font(.title2.weight(.bold))
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 168)
        .padding(.horizontal, 16)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke))
    }

    private func options(_ q: QuizQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(q.options, id: \.self) { option in
                let isAnswer = option == q.answer
                let state: Color? = selected == nil ? nil : (isAnswer ? Theme.correct : (option == selected ? Theme.wrong : nil))
                Button { answer(option, q) } label: {
                    Text(q.kind == .chooseMeaning ? GameRules.shortMeaning(option) : option)
                        .font(q.kind == .chooseMeaning ? .subheadline.weight(.semibold) : Theme.wordFont(19))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background((state ?? .clear).opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(state ?? Theme.stroke, lineWidth: state == nil ? 1 : 1.5))
                }
                .buttonStyle(PressableStyle())
                .disabled(selected != nil)
                .accessibilityLabel(q.kind == .chooseMeaning ? GameRules.shortMeaning(option) : option)
            }
        }
    }

    // MARK: - Flow

    private func start() {
        deadline = Date().addingTimeInterval(TimeInterval(GameRules.blitzSeconds))
        nextQuestion()
        withAnimation(.easeOut(duration: 0.25)) { phase = .playing }
    }

    private func nextQuestion() {
        let candidates = pool.count > 1 ? pool.filter { $0.wordKey != question?.record.wordKey } : pool
        guard let record = candidates.randomElement() else { return }
        let kind: QuestionKind = Bool.random() ? .chooseMeaning : .chooseWord
        selected = nil
        question = QuestionFactory.make(for: record, pool: WordData.pool(for: record), kind: kind)
    }

    private func answer(_ option: String, _ q: QuizQuestion) {
        guard selected == nil, case .playing = phase else { return }
        let isCorrect = option == q.answer
        selected = option
        answered += 1
        lastCorrect = isCorrect
        feedbackTick += 1
        withAnimation(.spring(duration: 0.3)) {
            if isCorrect {
                combo += 1
                bestCombo = max(bestCombo, combo)
                correct += 1
                let points = GameRules.blitzPoints(combo: combo)
                score += points
                lastGain = Gain(text: "+\(points)", positive: true)
            } else {
                combo = 0
                missed.append(q.record)
                deadline = deadline.addingTimeInterval(-TimeInterval(GameRules.blitzPenalty))
                lastGain = Gain(text: "-\(GameRules.blitzPenalty) 秒", positive: false)
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(isCorrect ? 280 : 650))
            guard case .playing = phase else { return }
            withAnimation(.spring(duration: 0.3)) { nextQuestion() }
        }
    }

    private func finish() {
        guard case .playing = phase else { return }
        let previous = GameRules.best(.blitz, in: vm.state.gameRecords)
        isRecord = score > 0 && score > (previous ?? 0)
        coins = vm.recordGame(.blitz, score: score, correct: correct, total: answered)
        withAnimation(.easeInOut(duration: 0.3)) { phase = .over }
    }
}
