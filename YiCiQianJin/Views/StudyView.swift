import SwiftUI

struct StudyView: View {
    let word: Word
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("今日单词")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))

                Text(word.word)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)

                Text(word.phonetic)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))

                Text(word.meaning)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 4) {
                    Text("请认真记住这个单词")
                    Text("明天将会考你哦")
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 8)

                Button(action: onConfirm) {
                    Text("我已经记住了")
                        .font(.headline)
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)

            Spacer()

            Text("每天只能背一个词，这就是「一词千金」的规矩")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 24)
        }
    }
}
