import SwiftUI

/// Learn one word: recall first, reveal the meaning, then write it from memory once.
struct StudyView: View {
    @Bindable var vm: StudyViewModel
    let word: Word

    @State private var revealed = false
    @State private var spelling = ""
    @State private var spelledCorrectly = false
    @State private var wrongAttempts = 0
    @FocusState private var spellingFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var atlas: AtlasEntry? { WordAtlas.entry(for: word.word) }

    var body: some View {
        AdaptiveSplit {
            // Wide / folded: picture + headword on one side, meaning and practice on the other.
            // Leave room under the picture so the headword card stays on screen in landscape.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        progressLabel
                        illustration(maxSide: min(420, max(200, proxy.size.height - 240)))
                        wordCard(showMeaning: false)
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
        } secondary: {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        meaningArea
                        detailCards
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                if !spellingFocused { bottomBar }
            }
        } compact: {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 18) {
                            progressLabel
                            // Keep picture, word and meaning on one screen on short displays
                            // (e.g. iPhone Duo outer display).
                            illustration(maxSide: min(300, proxy.size.height * 0.34))
                            wordCard(showMeaning: true)
                            detailCards
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                        .readableWidth()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // While writing from memory the keyboard needs the room; submit via 检查 / return.
                    if !spellingFocused { bottomBar.readableWidth() }
                }
            }
        }
        .pageChrome(vm.hasStudiedToday ? "继续学新词" : "今日一词", backLabel: "关闭") { vm.go(.home) }
        .sensoryFeedback(.success, trigger: spelledCorrectly) { _, new in new }
        .sensoryFeedback(.error, trigger: wrongAttempts)
        .onAppear {
            if vm.state.autoPronounce { Pronouncer.shared.speak(word.word) }
        }
    }

    // MARK: - Word

    private var progressLabel: some View {
        Text("\(vm.currentBook?.name ?? "") · 第 \(vm.state.currentWordIndex + 1) 个词")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)
    }

    /// One word, one picture: the illustration is a recall cue before the meaning is revealed.
    @ViewBuilder
    private func illustration(maxSide: CGFloat) -> some View {
        if atlas?.imageID != nil {
            WordIllustration(word: word.word, cornerRadius: 26)
                .frame(maxWidth: maxSide)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private var detailCards: some View {
        if revealed {
            Group {
                if let examples = atlas?.examples, !examples.isEmpty {
                    ExampleSentences(word: word.word, examples: examples)
                        .card()
                }
                if let tip = atlas?.tip {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Theme.gold)
                        Text(tip)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card(padding: 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("用法提示：\(tip)")
                }
                spellingCard
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func wordCard(showMeaning: Bool) -> some View {
        VStack(spacing: 14) {
            Text(word.word)
                .font(Theme.wordFont(46))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .blur(radius: spellingFocused && !spelledCorrectly ? 14 : 0)
                .animation(.easeInOut(duration: 0.25), value: spellingFocused)
                .accessibilityHidden(spellingFocused && !spelledCorrectly)
                .accessibilityIdentifier("studyWord")

            HStack(spacing: 12) {
                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }
                SpeakButton(text: word.word, size: 36)
                Button {
                    Pronouncer.shared.speak(word.word, slow: true)
                } label: {
                    Image(systemName: "tortoise.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface, in: Circle())
                }
                .accessibilityLabel("慢速朗读")
            }

            if showMeaning {
                meaningArea
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.stroke))
    }

    @ViewBuilder
    private var meaningArea: some View {
        if revealed {
            Text(word.meaning)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 88)
                .padding(.horizontal, 12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity))
        } else {
            Button(action: reveal) {
                VStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.gold)
                    Text("先在心里想想它的意思")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("点击揭晓释义")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 88)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func reveal() {
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { revealed = true }
    }

    // MARK: - Spelling

    private var spellingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("默写一遍，记得更牢")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("输入时单词会被遮住")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            if spelledCorrectly {
                Label("默写正确，记住啦！", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.correct)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.correct.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    TextField("", text: $spelling, prompt: Text("输入这个单词").foregroundStyle(Theme.textTertiary))
                        .focused($spellingFocused)
                        .accessibilityIdentifier("spellField")
                        .accessibilityLabel("默写单词")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(checkSpelling)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(wrongAttempts > 0 ? Theme.wrong.opacity(0.7) : Theme.stroke))
                        .modifier(Shake(animatableData: CGFloat(wrongAttempts)))
                    Button("检查", action: checkSpelling)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.onGold)
                        .frame(width: 64, height: 48)
                        .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(spelling.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if wrongAttempts > 0 {
                    Text("还差一点，收起键盘再看一眼单词吧")
                        .font(.caption)
                        .foregroundStyle(Theme.wrong)
                }
            }
        }
        .card()
    }

    private func checkSpelling() {
        if AnswerMatcher.matches(spelling, word.word) {
            spellingFocused = false
            withAnimation(.spring(duration: 0.35)) { spelledCorrectly = true }
            Pronouncer.shared.speak(word.word)
        } else {
            withAnimation(.default) { wrongAttempts += 1 }
        }
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if revealed {
                Button {
                    spellingFocused = false
                    vm.markWordStudied()
                } label: {
                    Label("收入词库 · +\(LearningStats.Reward.newWord) 金", systemImage: "plus.circle.fill")
                }
                .buttonStyle(GoldButtonStyle())
            } else {
                Button("揭晓释义", action: reveal)
                    .buttonStyle(GlassButtonStyle(height: 54))
            }
            Text("5 分钟后第一次复习，明天还会考你这个词")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

/// Horizontal shake used for wrong answers.
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}
