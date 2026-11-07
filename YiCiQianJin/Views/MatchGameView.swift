import SwiftUI

/// 词义配对: match five words with their meanings, three rounds, against the clock.
struct MatchGameView: View {
    @Bindable var vm: StudyViewModel
    @State private var session = 0

    var body: some View {
        MatchSession(vm: vm, onReplay: { session += 1 })
            .id(session)
            .navigationTitle(GameKind.match.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { vm.go(.games) } label: {
                        Label("退出词义配对", systemImage: "xmark")
                    }
                }
            }
    }
}

private struct MatchSession: View {
    let vm: StudyViewModel
    let onReplay: () -> Void

    private struct Tile: Identifiable, Equatable {
        let id: String      // word key, shared by the word tile and its meaning tile
        let text: String
    }

    @State private var rounds: [[StudyRecord]] = []
    @State private var round = 0
    @State private var words: [Tile] = []
    @State private var meanings: [Tile] = []
    @State private var matched: Set<String> = []
    @State private var pickedWord: String?
    @State private var pickedMeaning: String?
    @State private var wrongPair: (word: String, meaning: String)?
    @State private var shakeTick: CGFloat = 0
    @State private var mistakes = 0
    @State private var missed: [StudyRecord] = []
    @State private var start = Date()
    @State private var elapsed = 0
    @State private var finished = false
    @State private var coins = 0
    @State private var isRecord = false
    @State private var matchTick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if finished {
                GameSummaryView(
                    title: "全部配对完成",
                    value: GameFormat.clock(elapsed),
                    unit: "用时",
                    isRecord: isRecord,
                    stats: [("配对", "\(rounds.joined().count)"), ("配错", "\(mistakes)")],
                    coins: coins,
                    missed: missed.uniqueWords(),
                    onReplay: onReplay,
                    onExit: { vm.finishGame() })
                .transition(.opacity)
            } else {
                board
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: matchTick)
        .sensoryFeedback(.error, trigger: mistakes)
        .onAppear(perform: setUp)
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: 16) {
            HStack {
                Text("第 \(round + 1)/\(max(rounds.count, 1)) 轮")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(GameFormat.clock(Int(context.date.timeIntervalSince(start))))
                        .font(.system(size: 28, weight: .semibold, design: .serif).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            CapsuleBar(progress: Double(matched.count) / Double(max(words.count, 1)), height: 6)

            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(words) { tile in
                        tileButton(tile, isWord: true)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(meanings) { tile in
                        tileButton(tile, isWord: false)
                    }
                }
            }
            .id(round)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))

            Text("先点单词，再点它的意思")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .readableWidth(600)
    }

    private func tileButton(_ tile: Tile, isWord: Bool) -> some View {
        let done = matched.contains(tile.id)
        let picked = isWord ? pickedWord == tile.id : pickedMeaning == tile.id
        let wrong = isWord ? wrongPair?.word == tile.id : wrongPair?.meaning == tile.id
        let border: Color = done ? Theme.correct : (wrong ? Theme.wrong : (picked ? Theme.gold : Theme.stroke))

        return Button { tap(tile, isWord: isWord) } label: {
            Text(tile.text)
                .font(isWord ? Theme.wordFont(18) : .subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(picked ? Theme.gold.opacity(0.14) : (done ? Theme.correct.opacity(0.12) : Theme.surface),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(border, lineWidth: border == Theme.stroke ? 1 : 1.5))
                .modifier(Shake(animatableData: wrong ? shakeTick : 0))
                .opacity(done ? 0.35 : 1)
                .scaleEffect(done && !reduceMotion ? 0.94 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(done)
        .accessibilityLabel(tile.text)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    // MARK: - Flow

    private func setUp() {
        guard rounds.isEmpty else { return }
        var used = Set<String>()
        let candidates = vm.learnedWords.shuffled().filter { used.insert(GameRules.shortMeaning($0.meaning)).inserted }
        let per = GameRules.matchPairsPerRound
        let count = min(GameRules.matchRounds, max(candidates.count / per, 1))
        rounds = (0..<count).map { Array(candidates.dropFirst($0 * per).prefix(per)) }
        start = Date()
        load(round: 0)
    }

    private func load(round index: Int) {
        let records = rounds[index]
        round = index
        matched = []
        pickedWord = nil
        pickedMeaning = nil
        words = records.map { Tile(id: $0.wordKey, text: $0.word) }.shuffled()
        meanings = records.map { Tile(id: $0.wordKey, text: GameRules.shortMeaning($0.meaning)) }.shuffled()
    }

    private func tap(_ tile: Tile, isWord: Bool) {
        guard wrongPair == nil else { return }
        if isWord {
            pickedWord = pickedWord == tile.id ? nil : tile.id
        } else {
            pickedMeaning = pickedMeaning == tile.id ? nil : tile.id
        }
        guard let w = pickedWord, let m = pickedMeaning else { return }

        if w == m {
            withAnimation(.spring(duration: 0.35)) {
                matched.insert(w)
                pickedWord = nil
                pickedMeaning = nil
            }
            matchTick += 1
            if vm.state.autoPronounce, let tile = words.first(where: { $0.id == w }) {
                Pronouncer.shared.speak(tile.text)
            }
            if matched.count == words.count { roundCleared() }
        } else {
            mistakes += 1
            if let record = rounds[round].first(where: { $0.wordKey == w }) { missed.append(record) }
            wrongPair = (w, m)
            withAnimation(.default) { shakeTick += 1 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.2)) {
                    wrongPair = nil
                    pickedWord = nil
                    pickedMeaning = nil
                }
            }
        }
    }

    private func roundCleared() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if round + 1 < rounds.count {
                withAnimation(.spring(duration: 0.4)) { load(round: round + 1) }
            } else {
                finish()
            }
        }
    }

    private func finish() {
        elapsed = Int(Date().timeIntervalSince(start).rounded())
        let pairs = rounds.joined().count
        let previous = GameRules.best(.match, in: vm.state.gameRecords)
        isRecord = previous.map { elapsed < $0 } ?? true
        coins = vm.recordGame(.match, score: elapsed, correct: pairs, total: pairs)
        withAnimation(.easeInOut(duration: 0.3)) { finished = true }
    }
}
