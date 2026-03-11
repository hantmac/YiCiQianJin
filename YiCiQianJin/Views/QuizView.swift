import SwiftUI

struct QuizView: View {
    let wordsToQuiz: [StudyRecord]
    let onPass: () -> Void
    let onFail: (StudyRecord) -> Void
    let onRecord: (String, Bool) -> Void

    @State private var currentIndex = 0
    @State private var input = ""
    @State private var selectedOption: Int? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var allPassed = true
    @State private var failedRecord: StudyRecord?
    @State private var quizType: QuizType = .fillBlank
    @State private var blankedDisplay = ""
    @State private var options: [String] = []

    private var currentRecord: StudyRecord {
        wordsToQuiz[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                HStack {
                    Text("每日考试")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("\(currentIndex + 1) / \(wordsToQuiz.count)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                quizContent

                if showResult {
                    resultView
                }

                actionButton
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)

            Spacer()
        }
        .onAppear { setupQuiz() }
    }

    @ViewBuilder
    private var quizContent: some View {
        switch quizType {
        case .fillBlank:
            fillBlankView
        case .chooseMeaning:
            chooseMeaningView
        case .writeWord:
            writeWordView
        }
    }

    private var fillBlankView: some View {
        VStack(spacing: 12) {
            Text("填写缺失的字母")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text("中文含义：\(currentRecord.meaning)")
                .foregroundStyle(.white)
            Text(blankedDisplay)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .tracking(4)
            if !showResult {
                TextField("输入完整单词", text: $input)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { checkAnswer() }
            }
        }
    }

    private var chooseMeaningView: some View {
        VStack(spacing: 16) {
            Text("选择正确的中文意思")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text(currentRecord.word)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            if !showResult {
                ForEach(Array(options.enumerated()), id: \.offset) { i, opt in
                    Button {
                        selectedOption = i
                    } label: {
                        HStack {
                            Text("\(Character(UnicodeScalar(65 + i)!)). \(opt)")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding()
                        .background(selectedOption == i ? .white.opacity(0.3) : .white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedOption == i ? .white.opacity(0.6) : .white.opacity(0.2))
                        )
                    }
                }
            }
        }
    }

    private var writeWordView: some View {
        VStack(spacing: 12) {
            Text("根据中文意思写出单词")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Text(currentRecord.meaning)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            if !showResult {
                TextField("输入英文单词", text: $input)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { checkAnswer() }
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 4) {
            Text(isCorrect ? "正确!" : "错误!")
                .font(.title2.bold())
                .foregroundStyle(isCorrect ? .green : .red)
            Text("正确答案：\(currentRecord.word) - \(currentRecord.meaning)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .background((isCorrect ? Color.green : Color.red).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButton: some View {
        Group {
            if !showResult {
                Button(action: checkAnswer) {
                    Text("确认答案")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(quizType == .chooseMeaning ? selectedOption == nil : input.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity((quizType == .chooseMeaning ? selectedOption == nil : input.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.4 : 1)
            } else {
                Button(action: handleNext) {
                    Text(currentIndex < wordsToQuiz.count - 1 ? "下一题" : "完成考试")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Logic

    private func setupQuiz() {
        quizType = QuizType.allCases.randomElement()!
        generateBlanked()
        generateOptions()
    }

    private func generateBlanked() {
        let w = currentRecord.word
        let chars = Array(w)
        let blankCount = max(1, Int(Double(chars.count) * 0.4))
        var indices = Set<Int>()
        while indices.count < blankCount {
            indices.insert(Int.random(in: 0..<chars.count))
        }
        blankedDisplay = String(chars.enumerated().map { indices.contains($0.offset) ? Character("_") : $0.element })
    }

    private func generateOptions() {
        let book = WordData.books.first { $0.id == currentRecord.bookId }
        let allMeanings = book?.words.map(\.meaning) ?? []
        let correct = currentRecord.meaning
        let wrong = allMeanings.filter { $0 != correct }.shuffled().prefix(3)
        options = ([correct] + wrong).shuffled()
    }

    private func checkAnswer() {
        let correct: Bool
        switch quizType {
        case .fillBlank, .writeWord:
            correct = input.trimmingCharacters(in: .whitespaces).lowercased() == currentRecord.word.lowercased()
        case .chooseMeaning:
            correct = selectedOption != nil && options[selectedOption!] == currentRecord.meaning
        }
        isCorrect = correct
        showResult = true
        onRecord(currentRecord.word, correct)
        if !correct {
            allPassed = false
            failedRecord = currentRecord
        }
    }

    private func handleNext() {
        if currentIndex < wordsToQuiz.count - 1 {
            currentIndex += 1
            input = ""
            selectedOption = nil
            showResult = false
            setupQuiz()
        } else {
            if allPassed {
                onPass()
            } else {
                onFail(failedRecord ?? wordsToQuiz[0])
            }
        }
    }
}
