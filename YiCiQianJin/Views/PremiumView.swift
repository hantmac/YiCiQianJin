import SwiftUI

struct PremiumView: View {
    @Bindable var vm: StudyViewModel

    private var store: StoreManager { vm.storeManager }

    var body: some View {
        // Scrolls on short displays (e.g. iPhone Duo outer display), centered otherwise.
        GeometryReader { proxy in
          ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.goldGradient)
                    .symbolEffect(.bounce, value: vm.state.isPremium)

                Text("小象单词 Pro")
                    .font(.title.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("解锁无限背单词，不再受每日一词的限制")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                featuresCard
                priceSection
                errorSection
                actionSection
            }
            .padding(24)
            .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.gold.opacity(0.3)))
            .padding()
            .readableWidth(520)
            .frame(minHeight: proxy.size.height)
          }
          .scrollBounceBehavior(.basedOnSize)
        }
        .pageChrome("") { vm.go(.home) }
        .task {
            if store.product == nil && !store.isLoadingProducts {
                await store.loadProducts()
            }
        }
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow("每天背无限个单词")
            featureRow("昨日考试可选，不再卡住新词")
            featureRow("支持开发者买杯咖啡")
        }
        .card(padding: 16, radius: 16)
    }

    @ViewBuilder
    private var priceSection: some View {
        VStack(spacing: 4) {
            if let product = store.product {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("/永久")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else if store.isLoadingProducts {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 8)
            } else {
                Text("商品信息加载失败")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 4)
                Button {
                    Task { await store.loadProducts() }
                } label: {
                    Text("点击重试")
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                }
            }
            Text("（反人类价格，配反人类APP）")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = store.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(Theme.wrong)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        if vm.state.isPremium {
            Label("已是尊贵的 Pro 用户", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Theme.correct)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Theme.correct.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            VStack(spacing: 12) {
                Button {
                    Task { await vm.upgradeToPremium() }
                } label: {
                    HStack {
                        if store.isLoading {
                            ProgressView().tint(Theme.onGold)
                        }
                        Text(store.isLoading ? "购买中..." : "立即升级")
                    }
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(store.isLoading || store.product == nil)

                Button {
                    Task {
                        await store.restorePurchases()
                        if store.isPurchased { vm.state.isPremium = true }
                    }
                } label: {
                    Text("恢复购买")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .disabled(store.isLoading)
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.gold)
            Text(text)
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
