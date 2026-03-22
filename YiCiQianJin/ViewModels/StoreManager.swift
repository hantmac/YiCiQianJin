import Foundation
import StoreKit

@Observable
class StoreManager {
    static let productId = "com.yiciqianjin.app.pro"

    private(set) var product: Product?
    private(set) var isPurchased = false
    private(set) var isLoading = false
    private(set) var isLoadingProducts = false
    private(set) var errorMessage: String?

    private var transactionListener: Task<Void, Error>?

    private enum LoadError: Error {
        case timeout
    }

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await checkPurchased()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    @MainActor
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        errorMessage = nil

        do {
            let products = try await withThrowingTaskGroup(of: [Product].self) { group in
                group.addTask {
                    try await Product.products(for: [Self.productId])
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw LoadError.timeout
                }
                guard let result = try await group.next() else {
                    throw LoadError.timeout
                }
                group.cancelAll()
                return result
            }
            product = products.first
            if product == nil {
                errorMessage = "未找到商品信息，请稍后重试"
            }
        } catch is LoadError {
            errorMessage = "加载商品信息超时，请检查网络后重试"
        } catch {
            errorMessage = "无法加载商品信息: \(error.localizedDescription)"
        }

        isLoadingProducts = false
    }

    // MARK: - Purchase

    @MainActor
    func purchase() async -> Bool {
        guard let product else {
            errorMessage = "商品信息未加载"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = true
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                errorMessage = "购买正在等待审批"
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "购买失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkPurchased()
            if !isPurchased {
                errorMessage = "未找到可恢复的购买记录"
            }
        } catch {
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Check Purchased

    @MainActor
    func checkPurchased() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productId,
               transaction.revocationDate == nil {
                isPurchased = true
                return
            }
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    if transaction.productID == Self.productId {
                        await MainActor.run {
                            self.isPurchased = transaction.revocationDate == nil
                        }
                    }
                    await transaction.finish()
                case .unverified(let transaction, _):
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
