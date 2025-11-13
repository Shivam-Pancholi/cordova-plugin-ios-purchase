//
//  TransactionObserver.swift
//  iOSPurchasePlugin
//
//  Observer for transaction updates and webhook notifications
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
class TransactionObserver {

    // MARK: - Properties
    private var updateTask: Task<Void, Error>?
    private var callbacks: [(TransactionInfo) -> Void] = []

    // MARK: - Initialization
    init() {
        updateTask = observeTransactions()
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Public Methods

    /// Register a callback for transaction updates
    /// - Parameter callback: Closure to call when transactions update
    func registerCallback(_ callback: @escaping (TransactionInfo) -> Void) {
        callbacks.append(callback)
    }

    /// Clear all callbacks
    func clearCallbacks() {
        callbacks.removeAll()
    }

    // MARK: - Private Methods

    /// Observe transaction updates
    /// - Returns: Task for observing transactions
    private func observeTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }

            // Listen for transaction updates
            for await verificationResult in Transaction.updates {
                do {
                    // Verify the transaction
                    let transaction = try self.checkVerified(verificationResult)

                    // Create transaction info
                    let transactionInfo = TransactionInfo(from: transaction)

                    // Notify all callbacks
                    for callback in self.callbacks {
                        callback(transactionInfo)
                    }

                    // Finish the transaction
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    /// Verify transaction result
    /// - Parameter result: VerificationResult to check
    /// - Returns: Verified Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw NSError(
                domain: "TransactionObserver",
                code: PurchaseError.verificationFailed.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed: \(error)"]
            )
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Legacy StoreKit 1 Support (iOS 14 and below)

/// Transaction observer for backward compatibility with iOS 14 and below
class TransactionObserverCompat: NSObject, SKPaymentTransactionObserver {

    // MARK: - Properties
    var transactionUpdateCallback: (([SKPaymentTransaction]) -> Void)?

    // MARK: - Initialization
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // Notify callback with all transactions
        transactionUpdateCallback?(transactions)

        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored, .failed:
                // Finish the transaction
                queue.finishTransaction(transaction)

            case .purchasing, .deferred:
                // Transaction is in progress
                break

            @unknown default:
                break
            }
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        // Handle removed transactions if needed
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        // Restore completed successfully
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        // Restore failed
        print("Restore failed: \(error.localizedDescription)")
    }
}

/// Observer for StoreKit 1 transactions (iOS 14 and below)
@available(iOS 14.0, *)
class LegacyTransactionObserver: NSObject, SKPaymentTransactionObserver {

    // MARK: - Properties
    private var callbacks: [(SKPaymentTransaction) -> Void] = []

    // MARK: - Initialization
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }

    // MARK: - Public Methods

    /// Register a callback for transaction updates
    /// - Parameter callback: Closure to call when transactions update
    func registerCallback(_ callback: @escaping (SKPaymentTransaction) -> Void) {
        callbacks.append(callback)
    }

    /// Clear all callbacks
    func clearCallbacks() {
        callbacks.removeAll()
    }

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                // Notify callbacks
                for callback in callbacks {
                    callback(transaction)
                }

                // Finish the transaction
                queue.finishTransaction(transaction)

            case .failed:
                // Notify callbacks with error
                for callback in callbacks {
                    callback(transaction)
                }

                // Finish the transaction
                queue.finishTransaction(transaction)

            case .purchasing, .deferred:
                // Transaction is in progress
                break

            @unknown default:
                break
            }
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        // Handle removed transactions if needed
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        // Restore completed successfully
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        // Restore failed
        print("Restore failed: \(error.localizedDescription)")
    }
}
