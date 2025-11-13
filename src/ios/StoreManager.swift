//
//  StoreManager.swift
//  iOSPurchasePlugin
//
//  Core StoreKit 2 manager for handling all in-app purchase operations
//

import Foundation
import StoreKit
import UIKit

@available(iOS 15.0, *)
class StoreManager: ObservableObject {

    // MARK: - Singleton
    static let shared = StoreManager()

    // MARK: - Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []

    private var updateListenerTask: Task<Void, Error>? = nil
    private var productIDs: [String] = []

    // Transaction callback for Cordova
    var transactionUpdateCallback: ((TransactionInfo) -> Void)?

    // MARK: - Initialization
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load purchased products from keychain
        Task {
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Load products from the App Store
    /// - Parameter productIDs: Array of product identifiers
    /// - Returns: Array of ProductInfo objects
    func loadProducts(productIDs: [String]) async throws -> [ProductInfo] {
        self.productIDs = productIDs

        do {
            // Request products from the App Store
            let storeProducts = try await Product.products(for: productIDs)

            // Update local cache
            self.products = storeProducts

            // Convert to ProductInfo
            let productInfos = storeProducts.map { ProductInfo(from: $0) }

            return productInfos
        } catch {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.networkError.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load products: \(error.localizedDescription)"]
            )
        }
    }

    /// Get a single product by ID
    /// - Parameter productID: The product identifier
    /// - Returns: ProductInfo object or nil
    func getProduct(productID: String) async throws -> ProductInfo? {
        // Check if product is already loaded
        if let product = products.first(where: { $0.id == productID }) {
            return ProductInfo(from: product)
        }

        // Load from App Store
        let loadedProducts = try await loadProducts([productID])
        return loadedProducts.first
    }

    // MARK: - Purchase

    /// Purchase a product
    /// - Parameters:
    ///   - productID: The product identifier to purchase
    ///   - offerID: Optional promotional offer identifier (requires server-side signature)
    /// - Returns: TransactionInfo object
    func purchase(productID: String, offerID: String? = nil) async throws -> TransactionInfo {
        // Find the product
        guard let product = products.first(where: { $0.id == productID }) else {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.invalidProductID.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Product not found: \(productID)"]
            )
        }

        // NOTE: Promotional offers require server-signed tokens in StoreKit 2
        // For now, we'll purchase without promotional offers
        // To implement promotional offers, you need to:
        // 1. Generate signature on your server using App Store Connect API
        // 2. Pass the signed offer data to the app
        // 3. Use Product.PurchaseOption.promotionalOffer with the signature

        if offerID != nil {
            // Log that promotional offers are not yet fully implemented
            print("Warning: Promotional offers require server-side implementation")
        }

        do {
            // Initiate purchase (without promotional offer for now)
            let result = try await product.purchase()

            // Handle purchase result
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try checkVerified(verification)

                // Update purchased products
                await updatePurchasedProducts()

                // Finish the transaction
                await transaction.finish()

                // Return transaction info
                return TransactionInfo(from: transaction)

            case .userCancelled:
                throw NSError(
                    domain: "StoreManager",
                    code: PurchaseError.userCancelled.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: PurchaseError.userCancelled.description]
                )

            case .pending:
                throw NSError(
                    domain: "StoreManager",
                    code: PurchaseError.pending.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: PurchaseError.pending.description]
                )

            @unknown default:
                throw NSError(
                    domain: "StoreManager",
                    code: PurchaseError.unknown.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: PurchaseError.unknown.description]
                )
            }
        } catch {
            // Handle purchase errors
            if let purchaseError = error as? StoreKitError {
                throw mapStoreKitError(purchaseError)
            } else {
                throw error
            }
        }
    }

    // MARK: - Restore Purchases

    /// Restore previously purchased products
    /// - Returns: Array of TransactionInfo objects
    func restorePurchases() async throws -> [TransactionInfo] {
        var restoredTransactions: [TransactionInfo] = []

        // Iterate through all transactions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                restoredTransactions.append(TransactionInfo(from: transaction))
            } catch {
                // Log verification failure but continue
                print("Failed to verify transaction: \(error)")
            }
        }

        // Update purchased products
        await updatePurchasedProducts()

        return restoredTransactions
    }

    // MARK: - Subscription Status

    /// Get subscription status for a product
    /// - Parameter productID: The subscription product identifier
    /// - Returns: SubscriptionStatusInfo object or nil
    func getSubscriptionStatus(productID: String) async throws -> SubscriptionStatusInfo? {
        // Find the product
        guard let product = products.first(where: { $0.id == productID }) else {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.invalidProductID.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Product not found: \(productID)"]
            )
        }

        // Check if it's a subscription
        guard let subscription = product.subscription else {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.invalidProductID.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Product is not a subscription: \(productID)"]
            )
        }

        // Get subscription status
        guard let status = try await subscription.status.first else {
            return nil
        }

        return await SubscriptionStatusInfo(from: status)
    }

    /// Get all subscription statuses for a group
    /// - Parameter groupID: The subscription group identifier
    /// - Returns: Array of SubscriptionStatusInfo objects
    func getSubscriptionGroupStatus(groupID: String) async throws -> [SubscriptionStatusInfo] {
        var statuses: [SubscriptionStatusInfo] = []

        // Find all products in the group
        let groupProducts = products.filter { product in
            product.subscription?.subscriptionGroupID == groupID
        }

        // Get status for each product
        for product in groupProducts {
            if let subscription = product.subscription {
                for status in try await subscription.status {
                    statuses.append(await SubscriptionStatusInfo(from: status))
                }
            }
        }

        return statuses
    }

    /// Get all subscription statuses for a group (alias for compatibility)
    /// - Parameter groupID: The subscription group identifier
    /// - Returns: Array of SubscriptionStatusInfo objects
    func getSubscriptionStatuses(groupID: String) async throws -> [SubscriptionStatusInfo] {
        return try await getSubscriptionGroupStatus(groupID: groupID)
    }

    // MARK: - Current Entitlements

    /// Get all current entitlements
    /// - Returns: Array of TransactionInfo objects for current entitlements
    func getCurrentEntitlements() async -> [TransactionInfo] {
        var entitlements: [TransactionInfo] = []

        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                entitlements.append(TransactionInfo(from: transaction))
            } catch {
                // Log verification failure but continue
                print("Failed to verify entitlement: \(error)")
            }
        }

        return entitlements
    }

    // MARK: - Refund Management

    /// Begin refund request for a transaction
    /// - Parameter transactionID: The transaction identifier
    /// - Returns: Refund status string
    func beginRefundRequest(transactionID: UInt64) async throws -> String {
        // Get the current window scene (iOS 15+)
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.unknown.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "No active window scene found"]
            )
        }

        // Find the transaction
        for await result in Transaction.all {
            do {
                let transaction = try checkVerified(result)

                if transaction.id == transactionID {
                    // Begin refund request (iOS 15.0+)
                    let status = try await transaction.beginRefundRequest(in: windowScene)

                    // Return status as string
                    switch status {
                    case .success:
                        return "success"
                    case .userCancelled:
                        return "userCancelled"
                    @unknown default:
                        return "unknown"
                    }
                }
            } catch {
                continue
            }
        }

        throw NSError(
            domain: "StoreManager",
            code: PurchaseError.invalidProductID.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Transaction not found: \(transactionID)"]
        )
    }

    // MARK: - Transaction Verification

    /// Check if a transaction is verified
    /// - Parameter result: VerificationResult
    /// - Returns: Verified Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.verificationFailed.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed: \(error)"]
            )
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener

    /// Listen for transaction updates
    /// - Returns: Task that listens for updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to purchase()
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Update purchased products
                    await self.updatePurchasedProducts()

                    // Notify callback
                    let transactionInfo = TransactionInfo(from: transaction)
                    self.transactionUpdateCallback?(transactionInfo)

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Purchased Products

    /// Update the set of purchased product identifiers
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            // Check if the transaction is still valid
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }

        self.purchasedProductIDs = purchased
    }

    /// Check if a product is purchased
    /// - Parameter productID: The product identifier
    /// - Returns: Boolean indicating if product is purchased
    func isPurchased(productID: String) -> Bool {
        return purchasedProductIDs.contains(productID)
    }

    /// Get all purchased product IDs
    /// - Returns: Array of product identifiers
    func getPurchasedProducts() -> [String] {
        return Array(purchasedProductIDs)
    }

    // MARK: - Receipt

    /// Get the app receipt URL
    /// - Returns: URL of the app receipt
    func getReceiptURL() -> URL? {
        return Bundle.main.appStoreReceiptURL
    }

    /// Get the app receipt data
    /// - Returns: Base64 encoded receipt data
    func getReceiptData() throws -> String {
        guard let receiptURL = getReceiptURL(),
              let receiptData = try? Data(contentsOf: receiptURL) else {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.receiptValidationFailed.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Receipt not found"]
            )
        }

        return receiptData.base64EncodedString()
    }

    // MARK: - Promotional Offers

    /// Redeem a promotional offer code
    /// - Parameter offerCode: The promotional offer code
    func redeemOfferCode(_ offerCode: String) async throws {
        #if targetEnvironment(simulator)
        throw NSError(
            domain: "StoreManager",
            code: PurchaseError.productNotAvailable.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Promotional offers are not available in simulator"]
        )
        #else
        if #available(iOS 16.0, *) {
            try await AppStore.presentOfferCodeRedeemSheet()
        } else {
            throw NSError(
                domain: "StoreManager",
                code: PurchaseError.productNotAvailable.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Offer code redemption requires iOS 16+"]
            )
        }
        #endif
    }

    // MARK: - Error Mapping

    /// Map StoreKitError to custom error
    /// - Parameter error: StoreKitError
    /// - Returns: NSError with custom error code
    private func mapStoreKitError(_ error: StoreKitError) -> NSError {
        let errorCode: PurchaseError
        let description: String

        switch error {
        case .userCancelled:
            errorCode = .userCancelled
            description = PurchaseError.userCancelled.description

        case .networkError:
            errorCode = .networkError
            description = PurchaseError.networkError.description

        case .notAvailableInStorefront:
            errorCode = .productNotAvailable
            description = PurchaseError.productNotAvailable.description

        case .notEntitled:
            errorCode = .purchaseNotAllowed
            description = PurchaseError.purchaseNotAllowed.description

        default:
            errorCode = .unknown
            description = error.localizedDescription
        }

        return NSError(
            domain: "StoreManager",
            code: errorCode.rawValue,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
