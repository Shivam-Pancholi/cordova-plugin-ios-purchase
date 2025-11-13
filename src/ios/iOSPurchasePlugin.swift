//
//  iOSPurchasePlugin.swift
//  iOSPurchasePlugin
//
//  Cordova plugin bridge for iOS In-App Purchases
//

import Foundation
import StoreKit

@objc(iOSPurchasePlugin)
class iOSPurchasePlugin: CDVPlugin {

    private var storeManager: StoreManager?
    private var transactionObserver: TransactionObserverCompat?

    // MARK: - Plugin Lifecycle

    override func pluginInitialize() {
        super.pluginInitialize()

        if #available(iOS 15.0, *) {
            storeManager = StoreManager.shared

            // Set up transaction update callback
            storeManager?.transactionUpdateCallback = { [weak self] transaction in
                self?.sendTransactionUpdate(transaction: transaction)
            }
        } else {
            // Fallback to StoreKit 1 for iOS 14 and below
            transactionObserver = TransactionObserverCompat()
            transactionObserver?.transactionUpdateCallback = { [weak self] transactions in
                self?.sendLegacyTransactionUpdate(transactions: transactions)
            }
        }

        // Listen for transaction notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransactionUpdate(_:)),
            name: NSNotification.Name("TransactionUpdated"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Product Management

    /// Fetch products from the App Store
    @objc(getProducts:)
    func getProducts(command: CDVInvokedUrlCommand) {
        guard let productIDs = command.argument(at: 0) as? [String] else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid product IDs")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        if #available(iOS 15.0, *) {
            Task {
                do {
                    let products = try await storeManager?.loadProducts(productIDs: productIDs) ?? []
                    let productsDict = products.map { $0.toDictionary() }

                    let result = CDVPluginResult(status: .ok, messageAs: productsDict)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch {
                    let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            // iOS 14 fallback
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Purchase Management

    /// Purchase a product
    @objc(purchase:)
    func purchase(command: CDVInvokedUrlCommand) {
        guard let productID = command.argument(at: 0) as? String else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid product ID")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        let offerID = command.argument(at: 1) as? String

        if #available(iOS 15.0, *) {
            Task {
                do {
                    let transaction: TransactionInfo

                    if let offer = offerID {
                        transaction = try await storeManager?.purchase(productID: productID, offerID: offer) ?? TransactionInfo(from: Transaction.currentEntitlements.first(where: { _ in true })!)
                    } else {
                        transaction = try await storeManager?.purchase(productID: productID) ?? TransactionInfo(from: Transaction.currentEntitlements.first(where: { _ in true })!)
                    }

                    let result = CDVPluginResult(status: .ok, messageAs: transaction.toDictionary())
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch let error as NSError {
                    let errorDict: [String: Any] = [
                        "code": error.code,
                        "message": error.localizedDescription
                    ]
                    let result = CDVPluginResult(status: .error, messageAs: errorDict)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    /// Restore purchases
    @objc(restorePurchases:)
    func restorePurchases(command: CDVInvokedUrlCommand) {
        if #available(iOS 15.0, *) {
            Task {
                do {
                    let transactions = try await storeManager?.restorePurchases() ?? []
                    let transactionsDict = transactions.map { $0.toDictionary() }

                    let result = CDVPluginResult(status: .ok, messageAs: transactionsDict)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch {
                    let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    /// Get current entitlements
    @objc(getCurrentEntitlements:)
    func getCurrentEntitlements(command: CDVInvokedUrlCommand) {
        if #available(iOS 15.0, *) {
            Task {
                let transactions = await storeManager?.getCurrentEntitlements() ?? []
                let transactionsDict = transactions.map { $0.toDictionary() }

                let result = CDVPluginResult(status: .ok, messageAs: transactionsDict)
                self.commandDelegate.send(result, callbackId: command.callbackId)
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    /// Check if a product is purchased
    @objc(isPurchased:)
    func isPurchased(command: CDVInvokedUrlCommand) {
        guard let productID = command.argument(at: 0) as? String else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid product ID")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        if #available(iOS 15.0, *) {
            Task {
                let purchased = await storeManager?.isPurchased(productID: productID) ?? false

                let result = CDVPluginResult(status: .ok, messageAs: purchased)
                self.commandDelegate.send(result, callbackId: command.callbackId)
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Subscription Management

    /// Get subscription status
    @objc(getSubscriptionStatus:)
    func getSubscriptionStatus(command: CDVInvokedUrlCommand) {
        guard let productID = command.argument(at: 0) as? String else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid product ID")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        if #available(iOS 15.0, *) {
            Task {
                do {
                    if let status = try await storeManager?.getSubscriptionStatus(productID: productID) {
                        let result = CDVPluginResult(status: .ok, messageAs: status.toDictionary())
                        self.commandDelegate.send(result, callbackId: command.callbackId)
                    } else {
                        let result = CDVPluginResult(status: .ok, messageAs: NSNull())
                        self.commandDelegate.send(result, callbackId: command.callbackId)
                    }
                } catch {
                    let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    /// Get subscription statuses for a group
    @objc(getSubscriptionStatuses:)
    func getSubscriptionStatuses(command: CDVInvokedUrlCommand) {
        guard let groupID = command.argument(at: 0) as? String else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid group ID")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        if #available(iOS 15.0, *) {
            Task {
                do {
                    let statuses = try await storeManager?.getSubscriptionStatuses(groupID: groupID) ?? []
                    let statusesDict = statuses.map { $0.toDictionary() }

                    let result = CDVPluginResult(status: .ok, messageAs: statusesDict)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch {
                    let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Receipt Management

    /// Get receipt data
    @objc(getReceipt:)
    func getReceipt(command: CDVInvokedUrlCommand) {
        if #available(iOS 15.0, *) {
            if let receiptData = ReceiptValidator.getReceiptData() {
                let receiptDict: [String: Any] = [
                    "receiptData": receiptData,
                    "hasReceipt": true
                ]
                let result = CDVPluginResult(status: .ok, messageAs: receiptDict)
                commandDelegate.send(result, callbackId: command.callbackId)
            } else {
                let receiptDict: [String: Any] = [
                    "hasReceipt": false
                ]
                let result = CDVPluginResult(status: .ok, messageAs: receiptDict)
                commandDelegate.send(result, callbackId: command.callbackId)
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    /// Refresh receipt
    @objc(refreshReceipt:)
    func refreshReceipt(command: CDVInvokedUrlCommand) {
        if #available(iOS 15.0, *) {
            Task {
                do {
                    try await ReceiptValidator.refreshReceipt()
                    let result = CDVPluginResult(status: .ok)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch {
                    let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Refund Management

    /// Begin refund request
    @objc(beginRefundRequest:)
    func beginRefundRequest(command: CDVInvokedUrlCommand) {
        guard let transactionIDString = command.argument(at: 0) as? String,
              let transactionID = UInt64(transactionIDString) else {
            let result = CDVPluginResult(status: .error, messageAs: "Invalid transaction ID")
            commandDelegate.send(result, callbackId: command.callbackId)
            return
        }

        if #available(iOS 15.0, *) {
            Task {
                do {
                    let status = try await storeManager?.beginRefundRequest(transactionID: transactionID) ?? "unknown"

                    let result = CDVPluginResult(status: .ok, messageAs: status)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch {
                    let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            }
        } else {
            let result = CDVPluginResult(status: .error, messageAs: "iOS 15.0 or higher required")
            commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Transaction Updates

    /// Handle transaction update notifications
    @objc private func handleTransactionUpdate(_ notification: Notification) {
        guard let transactionDict = notification.userInfo?["transaction"] as? [String: Any] else {
            return
        }

        sendEvent(name: "transactionUpdate", data: transactionDict)
    }

    /// Send transaction update to JavaScript
    private func sendTransactionUpdate(transaction: TransactionInfo) {
        sendEvent(name: "transactionUpdate", data: transaction.toDictionary())
    }

    /// Send legacy transaction update (StoreKit 1)
    private func sendLegacyTransactionUpdate(transactions: [SKPaymentTransaction]) {
        // Convert to simple format for JS
        let transactionsData = transactions.map { transaction -> [String: Any] in
            return [
                "transactionIdentifier": transaction.transactionIdentifier ?? "",
                "productIdentifier": transaction.payment.productIdentifier,
                "transactionDate": transaction.transactionDate?.timeIntervalSince1970 ?? 0,
                "transactionState": transaction.transactionState.rawValue
            ]
        }

        sendEvent(name: "transactionUpdate", data: transactionsData)
    }

    /// Send event to JavaScript
    private func sendEvent(name: String, data: Any) {
        let js = "cordova.fireDocumentEvent('\(name)', \(jsonString(from: data)));"
        commandDelegate.evalJs(js)
    }

    /// Convert object to JSON string
    private func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
