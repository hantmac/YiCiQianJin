import SwiftUI

struct BookSelectView: View {
    @Bindable var vm: StudyViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("一词千金")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("选择你的单词书，开始每日一词之旅")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)

                ForEach(WordData.books) { book in
                    Button {
                        vm.selectBook(book.id)
                    } label: {
                        HStack(spacing: 16) {
                            Text(book.icon)
                                .font(.system(size: 40))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(book.description)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding()
        }
    }
}
