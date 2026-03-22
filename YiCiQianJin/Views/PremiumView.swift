import SwiftUI

struct PremiumView: View {
    @Bindable var vm: StudyViewModel

    private var store: StoreManager { vm.storeManager }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    vm.currentPage = .home
                } label: {
                    Label("返回", systemImage: "chevron.left")
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding()

            Spacer()

            VStack(spacing: 20) {
                Text("👑")
                    .font(.system(size: 60))

                Text("一词千金 Pro")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("解锁无限背单词，不再受每日一词的限制")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                featuresCard
                priceSection
                errorSection
                actionSection
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)

            Spacer()
        }
        .task {
            if store.product == nil && !store.isLoadingProducts {
                await store.loadProducts()
            }
        }
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow("每天背无限个单词")
            featureRow("解锁全部单词书")
            featureRow("考试不通过也能继续背新词")
            featureRow("支持开发者买杯咖啡")
        }
        .padding()
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var priceSection: some View {
        VStack(spacing: 4) {
            Text("原价 ¥998/年")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .strikethrough()
            if let product = store.product {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                    Text("/永久")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else if store.isLoadingProducts {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 8)
            } else {
                Text("商品信息加载失败")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 4)
                Button {
                    Task { await store.loadProducts() }
                } label: {
                    Text("点击重试")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            Text("（反人类价格，配反人类APP）")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = store.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if vm.state.isPremium {
            Text("已是尊贵的 Pro 用户 👑")
                .font(.headline)
                .foregroundStyle(.green)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(spacing: 12) {
                Button {
                    Task { await vm.upgradeToPremium() }
                } label: {
                    HStack {
                        if store.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(store.isLoading ? "购买中..." : "立即升级")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(store.isLoading || store.product == nil)

                Button {
                    Task {
                        await store.restorePurchases()
                        if store.isPurchased { vm.state.isPremium = true }
                    }
                } label: {
                    Text("恢复购买")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .disabled(store.isLoading)
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .foregroundStyle(.white)
        }
    }
}
