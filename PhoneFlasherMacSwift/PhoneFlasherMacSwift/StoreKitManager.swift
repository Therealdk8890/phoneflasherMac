import Foundation
import StoreKit

// MARK: - Product Identifiers

enum AppProduct: String, CaseIterable {
    case pro = "com.danielkissel.PhoneFlasherMac.pro"

    var displayName: String {
        switch self {
        case .pro: return "PhoneFlasher Pro"
        }
    }

    var description: String {
        switch self {
        case .pro: return "Unlock all flashing features, vendor tools, and log export."
        }
    }
}

// MARK: - Pro Features

enum ProFeature: String, CaseIterable, Identifiable {
    case flashImages = "Flash Images"
    case vendorTools = "Vendor Tool Downloads"
    case logExport = "Export Logs"
    case batchFlash = "Batch Flash Mode"
    case prioritySupport = "Priority Support"
    case futureFeatures = "All Future Features"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flashImages: return "bolt.fill"
        case .vendorTools: return "wrench.and.screwdriver.fill"
        case .logExport: return "square.and.arrow.up.fill"
        case .batchFlash: return "rectangle.stack.fill"
        case .prioritySupport: return "person.fill.checkmark"
        case .futureFeatures: return "star.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .flashImages: return "Flash boot, recovery, system, and vendor images"
        case .vendorTools: return "Download Samsung, LG, and OnePlus tools"
        case .logExport: return "Save logs to file for troubleshooting"
        case .batchFlash: return "Flash multiple partitions in sequence"
        case .prioritySupport: return "Get help when you need it"
        case .futureFeatures: return "Every new feature, included forever"
        }
    }
}

// MARK: - Store Manager

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var isProUnlocked: Bool {
        purchasedProductIDs.contains(AppProduct.pro.rawValue)
    }

    private var transactionListener: Task<Void, Error>?

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIDs = AppProduct.allCases.map(\.rawValue)
            products = try await Product.products(for: productIDs)
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                return true

            case .userCancelled:
                return false

            case .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Pro Product Helper

    var proProduct: Product? {
        products.first { $0.id == AppProduct.pro.rawValue }
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    // Transaction verification failed
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var purchased = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                // Skip unverified
            }
        }

        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}

// MARK: - Store Error

enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed."
        }
    }
}
