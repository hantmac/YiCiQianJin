import SwiftUI

/// 词义配对: three rounds of five pairs against the clock. Rounds 1–2 match words to
/// meanings; the last round matches illustrations to words.
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
                    Button { vm.go(.discover) } label: {
                        Label("退出词义配对", systemImage: "xmark")
                    }
                }
            }
    }
}

private struct MatchSession: View {
    let vm: StudyViewModel
    let onReplay: () -> Void

    private enum Side { case left, right }

    private struct Tile: Identifiable, Equatable {
        let id: String      // word key, shared by both tiles of a pair
        let text: String
        let word: String
        let isPicture: Bool
    }

    private struct Round {
        let records: [StudyRecord]
        let pictures: Bool
    }

    private struct FrameKey: PreferenceKey {
        static var defaultValue: [String: CGRect] = [:]
        static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
            value.merge(nextValue()) { $1 }
        }
    }

    @State private var rounds: [Round] = []
    @State private var round = 0
    @State private var left: [Tile] = []
    @State private var right: [Tile] = []
    @State private var matched: Set<String> = []
    @State private var pickedLeft: String?
    @State private var pickedRight: String?
    @State private var wrongPair: (left: String, right: String)?
    @State private var shakeTick: CGFloat = 0
    @State private var frames: [String: CGRect] = [:]

    @State private var mistakes = 0
    @State private var roundMistakes = 0
    @State private var streak = 0
    @State private var missed: [StudyRecord] = []
    @State private var roundStart = Date()
    @State private var accumulated: TimeInterval = 0
    @State private var roundStars: [Int] = []
    @State private var banner: Int?
    @State private var firstPairDone = false

    @State private var finished = false
    @State private var elapsed = 0
    @State private var coins = 0
    @State private var isRecord = false
    @State private var hapticPair = 0
    @State private var hapticWrong = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if finished {
                GameSummaryView(
                    vm: vm,
                    title: "全部配对完成",
                    badge: .stars(roundStars.reduce(0, +), of: rounds.count * 3),
                    value: GameFormat.clock(elapsed),
                    unit: "用时",
                    isRecord: isRecord,
                    stats: [("配对", "\(rounds.reduce(0) { $0 + $1.records.count })"), ("配错", "\(mistakes)")],
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
        .sensoryFeedback(.impact(weight: .light, intensity: 0.9), trigger: hapticPair)
        .sensoryFeedback(.error, trigger: hapticWrong)
        .onAppear(perform: setUp)
    }

    // MARK: - Board

    private var currentRound: Round? { rounds.indices.contains(round) ? rounds[round] : nil }

    private var board: some View {
        VStack(spacing: 14) {
            header
            // Board sits low, within thumb reach.
            Spacer(minLength: 0)
            ZStack {
                HStack(alignment: .top, spacing: 12) {
                    column(left, side: .left)
                    column(right, side: .right)
                }
                .id(round)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
                .opacity(banner == nil ? 1 : 0.25)

                if let stars = banner {
                    roundBanner(stars)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .coordinateSpace(name: "board")
            .onPreferenceChange(FrameKey.self) { frames = $0 }

            if !firstPairDone || round == rounds.count - 1 && currentRound?.pictures == true && matched.isEmpty {
                Text(currentRound?.pictures == true ? "看图，点出画里的单词" : "点一个单词，再点它的意思")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .readableWidth(600)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ForEach(rounds.indices, id: \.self) { i in
                        roundDot(i)
                    }
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let running = banner == nil ? context.date.timeIntervalSince(roundStart) : 0
                    Text(GameFormat.clock(Int(accumulated + max(running, 0))))
                        .font(.system(size: 28, weight: .semibold, design: .serif).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            CapsuleBar(progress: Double(matched.count) / Double(max(left.count, 1)), height: 6)
                .animation(.spring(duration: 0.3), value: matched.count)
        }
    }

    /// Finished rounds show their stars; the current one is ringed.
    private func roundDot(_ i: Int) -> some View {
        Group {
            if i < roundStars.count {
                StarRow(filled: roundStars[i], size: 10)
            } else {
                Text(rounds[i].pictures ? "看图" : "第 \(i + 1) 轮")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(i == round ? Theme.gold : Theme.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(i == round && banner == nil ? Theme.gold.opacity(0.14) : Theme.surface, in: Capsule())
    }

    private func column(_ tiles: [Tile], side: Side) -> some View {
        VStack(spacing: 10) {
            ForEach(tiles) { tile in
                tileButton(tile, side: side)
            }
        }
    }

    private func key(_ id: String, _ side: Side) -> String { (side == .left ? "l|" : "r|") + id }

    private func tileButton(_ tile: Tile, side: Side) -> some View {
        let done = matched.contains(tile.id)
        let picked = side == .left ? pickedLeft == tile.id : pickedRight == tile.id
        let wrong = side == .left ? wrongPair?.left == tile.id : wrongPair?.right == tile.id
        let border: Color = wrong ? Theme.wrong : (picked ? Theme.gold : Theme.stroke)
        let height: CGFloat = currentRound?.pictures == true ? 76 : 64

        return Button { tap(tile, side: side) } label: {
            Group {
                if tile.isPicture {
                    WordIllustration(word: tile.word, cornerRadius: 12, maxPixel: 200)
                        .frame(width: height - 12, height: height - 12)
                } else {
                    Text(tile.text)
                        .font(side == .left || currentRound?.pictures == true ? Theme.wordFont(18) : .subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .background(picked ? Theme.gold.opacity(0.14) : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(border, lineWidth: border == Theme.stroke ? 1 : 1.5))
            // Measured before any offset, so the merge target doesn't move with the tile.
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: FrameKey.self, value: [key(tile.id, side): geo.frame(in: .named("board"))])
                }
            }
            .modifier(Shake(animatableData: wrong ? shakeTick : 0))
            // A matched pair flies together and vanishes, leaving an empty slot.
            .offset(done && !reduceMotion ? mergeOffset(tile.id, side) : .zero)
            .scaleEffect(done ? 0.6 : 1)
            .opacity(done ? 0 : 1)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .opacity(done ? 1 : 0)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(done || banner != nil)
        .zIndex(done ? 1 : 0)
        .accessibilityLabel(tile.isPicture ? "\(tile.word) 的插画" : tile.text)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private func mergeOffset(_ id: String, _ side: Side) -> CGSize {
        guard let a = frames[key(id, .left)], let b = frames[key(id, .right)] else { return .zero }
        let mid = CGPoint(x: (a.midX + b.midX) / 2, y: (a.midY + b.midY) / 2)
        let own = side == .left ? a : b
        return CGSize(width: mid.x - own.midX, height: mid.y - own.midY)
    }

    private func roundBanner(_ stars: Int) -> some View {
        VStack(spacing: 10) {
            Text("第 \(round + 1) 轮完成")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            StarRow(filled: stars, size: 34)
            Text(stars == 3 ? "又快又准" : (stars == 2 ? "很不错" : "下一轮再快一点"))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 36)
        .background(Theme.bgTop.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.gold.opacity(0.4)))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Flow

    private func setUp() {
        guard rounds.isEmpty else { return }
        GameSound.shared.prepareIfNeeded()
        let per = GameRules.matchPairsPerRound
        var used = Set<String>()
        var meanings = Set<String>()
        // Distinct meanings keep every pair unambiguous.
        let words = vm.learnedWords.shuffled().filter { meanings.insert(GameRules.shortMeaning($0.meaning)).inserted }
        func take(_ n: Int, where ok: (StudyRecord) -> Bool) -> [StudyRecord] {
            let picked = Array(words.filter { !used.contains($0.wordKey) && ok($0) }.prefix(n))
            picked.forEach { used.insert($0.wordKey) }
            return picked
        }

        var list: [Round] = []
        let textRounds = min(GameRules.matchRounds - 1, max(words.count / per, 1))
        for _ in 0..<textRounds {
            let r = take(per) { _ in true }
            if r.count >= 3 { list.append(Round(records: r, pictures: false)) }
        }
        let pictureRound = take(per) { WordAtlas.hasImage($0.word) }
        if pictureRound.count >= 3 {
            list.append(Round(records: pictureRound, pictures: true))
        } else if list.count < GameRules.matchRounds {
            let r = take(per) { _ in true }
            if r.count >= 3 { list.append(Round(records: r, pictures: false)) }
        }
        if list.isEmpty { list = [Round(records: Array(words.prefix(per)), pictures: false)] }
        rounds = list
        load(round: 0)
    }

    private func load(round index: Int) {
        let r = rounds[index]
        round = index
        matched = []
        pickedLeft = nil
        pickedRight = nil
        roundMistakes = 0
        if r.pictures {
            left = r.records.map { Tile(id: $0.wordKey, text: $0.word, word: $0.word, isPicture: true) }.shuffled()
            right = r.records.map { Tile(id: $0.wordKey, text: $0.word, word: $0.word, isPicture: false) }.shuffled()
        } else {
            left = r.records.map { Tile(id: $0.wordKey, text: $0.word, word: $0.word, isPicture: false) }.shuffled()
            right = r.records.map { Tile(id: $0.wordKey, text: GameRules.shortMeaning($0.meaning), word: $0.word, isPicture: false) }.shuffled()
        }
        roundStart = Date()
    }

    private func tap(_ tile: Tile, side: Side) {
        guard wrongPair == nil, banner == nil else { return }
        if side == .left {
            pickedLeft = pickedLeft == tile.id ? nil : tile.id
            // Hearing the word while choosing helps it stick.
            if vm.state.autoPronounce && pickedLeft != nil && !(currentRound?.pictures ?? false) {
                Pronouncer.shared.speak(tile.word)
            }
        } else {
            pickedRight = pickedRight == tile.id ? nil : tile.id
        }
        guard let l = pickedLeft, let r = pickedRight else { return }

        if l == r {
            streak += 1
            GameSound.shared.correct(combo: streak)
            hapticPair += 1
            withAnimation(.easeIn(duration: reduceMotion ? 0.15 : 0.32)) {
                matched.insert(l)
                pickedLeft = nil
                pickedRight = nil
                firstPairDone = true
            }
            if currentRound?.pictures == true, vm.state.autoPronounce { Pronouncer.shared.speak(tile.word) }
            if matched.count == left.count { roundCleared() }
        } else {
            streak = 0
            mistakes += 1
            roundMistakes += 1
            if let record = currentRound?.records.first(where: { $0.wordKey == l }) { missed.append(record) }
            GameSound.shared.play(.wrong)
            hapticWrong += 1
            wrongPair = (l, r)
            withAnimation(.default) { shakeTick += 1 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.2)) {
                    wrongPair = nil
                    pickedLeft = nil
                    pickedRight = nil
                }
            }
        }
    }

    private func roundCleared() {
        let seconds = Date().timeIntervalSince(roundStart)
        accumulated += seconds
        let stars = GameRules.matchStars(seconds: seconds, mistakes: roundMistakes, pairs: left.count)
        roundStars.append(stars)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(duration: 0.4, bounce: 0.35)) { banner = stars }
            for _ in 0..<stars {
                GameSound.shared.play(.star)
                try? await Task.sleep(for: .milliseconds(160))
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 500 : 800))
            if round + 1 < rounds.count {
                withAnimation(.spring(duration: 0.4)) {
                    banner = nil
                    load(round: round + 1)
                }
            } else {
                banner = nil
                finish()
            }
        }
    }

    private func finish() {
        elapsed = Int(accumulated.rounded())
        let pairs = rounds.reduce(0) { $0 + $1.records.count }
        let previous = GameRules.best(.match, in: vm.state.gameRecords)
        isRecord = previous.map { elapsed < $0 } ?? true
        coins = vm.recordGame(.match, score: elapsed, correct: pairs, total: pairs)
        withAnimation(.easeInOut(duration: 0.3)) { finished = true }
    }
}
