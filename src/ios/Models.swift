//
//  Models.swift
//  iOSPurchasePlugin
//
//  Data models for the iOS Purchase Plugin
//

import Foundation
import StoreKit

// MARK: - Product Information

@available(iOS 15.0, *)
struct ProductInfo: Codable {
    let id: String
    let displayName: String
    let description: String
    let price: Decimal
    let priceFormatted: String
    let currencyCode: String
    let type: String
    let subscriptionInfo: SubscriptionInfo?

    init(from product: Product) {
        self.id = product.id
        self.displayName = product.displayName
        self.description = product.description
        self.price = product.price
        self.priceFormatted = product.displayPrice
        self.currencyCode = product.priceFormatStyle.currencyCode

        switch product.type {
        case .consumable:
            self.type = "consumable"
        case .nonConsumable:
            self.type = "non-consumable"
        case .autoRenewable:
            self.type = "auto-renewable-subscription"
        case .nonRenewable:
            self.type = "non-renewing-subscription"
        @unknown default:
            self.type = "unknown"
        }

        self.subscriptionInfo = product.subscription.map { SubscriptionInfo(from: $0) }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "description": description,
            "price": NSDecimalNumber(decimal: price).doubleValue,
            "priceFormatted": priceFormatted,
            "currencyCode": currencyCode,
            "type": type
        ]

        if let subInfo = subscriptionInfo {
            dict["subscriptionInfo"] = subInfo.toDictionary()
        }

        return dict
    }
}

// MARK: - Subscription Information

@available(iOS 15.0, *)
struct SubscriptionInfo: Codable {
    let groupID: String
    let subscriptionPeriod: String
    let introductoryOffer: OfferInfo?
    let promotionalOffers: [OfferInfo]

    init(from subscription: Product.SubscriptionInfo) {
        self.groupID = subscription.subscriptionGroupID

        // Format subscription period
        let period = subscription.subscriptionPeriod
        self.subscriptionPeriod = "\(period.value) \(period.unit.description)"

        self.introductoryOffer = subscription.introductoryOffer.map { OfferInfo(from: $0) }
        self.promotionalOffers = subscription.promotionalOffers.map { OfferInfo(from: $0) }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "groupID": groupID,
            "subscriptionPeriod": subscriptionPeriod,
            "promotionalOffers": promotionalOffers.map { $0.toDictionary() }
        ]

        if let intro = introductoryOffer {
            dict["introductoryOffer"] = intro.toDictionary()
        }

        return dict
    }
}

// MARK: - Offer Information

@available(iOS 15.0, *)
struct OfferInfo: Codable {
    let id: String?
    let price: Decimal
    let priceFormatted: String
    let period: String
    let periodCount: Int
    let paymentMode: String

    init(from offer: Product.SubscriptionOffer) {
        self.id = offer.id
        self.price = offer.price
        self.priceFormatted = offer.displayPrice
        self.period = offer.period.unit.description
        self.periodCount = offer.period.value

        switch offer.paymentMode {
        case .payAsYouGo:
            self.paymentMode = "payAsYouGo"
        case .payUpFront:
            self.paymentMode = "payUpFront"
        case .freeTrial:
            self.paymentMode = "freeTrial"
        @unknown default:
            self.paymentMode = "unknown"
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "price": NSDecimalNumber(decimal: price).doubleValue,
            "priceFormatted": priceFormatted,
            "period": period,
            "periodCount": periodCount,
            "paymentMode": paymentMode
        ]

        if let offerId = id {
            dict["id"] = offerId
        }

        return dict
    }
}

// MARK: - Transaction Information

@available(iOS 15.0, *)
struct TransactionInfo: Codable {
    let id: UInt64
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date?
    let revocationDate: Date?
    let isUpgraded: Bool
    let offerID: String?
    let offerType: String?
    let environment: String
    let ownershipType: String

    init(from transaction: Transaction) {
        self.id = transaction.id
        self.productID = transaction.productID
        self.purchaseDate = transaction.purchaseDate
        self.expirationDate = transaction.expirationDate
        self.revocationDate = transaction.revocationDate
        self.isUpgraded = transaction.isUpgraded
        self.offerID = transaction.offerID

        if let offer = transaction.offerType {
            switch offer {
            case .introductory:
                self.offerType = "introductory"
            case .promotional:
                self.offerType = "promotional"
            @unknown default:
                self.offerType = "unknown"
            }
        } else {
            self.offerType = nil
        }

        // Environment property is only available in iOS 16.0+
        if #available(iOS 16.0, *) {
            switch transaction.environment {
            case .production:
                self.environment = "production"
            case .sandbox:
                self.environment = "sandbox"
            case .xcode:
                self.environment = "xcode"
            @unknown default:
                self.environment = "unknown"
            }
        } else {
            // For iOS 15, default to sandbox (can be detected from receipt)
            self.environment = "sandbox"
        }

        switch transaction.ownershipType {
        case .purchased:
            self.ownershipType = "purchased"
        case .familyShared:
            self.ownershipType = "familyShared"
        @unknown default:
            self.ownershipType = "unknown"
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": String(id),
            "productID": productID,
            "purchaseDate": purchaseDate.timeIntervalSince1970 * 1000,
            "isUpgraded": isUpgraded,
            "environment": environment,
            "ownershipType": ownershipType
        ]

        if let expDate = expirationDate {
            dict["expirationDate"] = expDate.timeIntervalSince1970 * 1000
        }

        if let revDate = revocationDate {
            dict["revocationDate"] = revDate.timeIntervalSince1970 * 1000
        }

        if let offer = offerID {
            dict["offerID"] = offer
        }

        if let offerT = offerType {
            dict["offerType"] = offerT
        }

        return dict
    }
}

// MARK: - Subscription Status

@available(iOS 15.0, *)
struct SubscriptionStatusInfo: Codable {
    let productID: String
    let state: String
    let renewalInfo: RenewalInfo?
    let transaction: TransactionInfo?

    init(from status: Product.SubscriptionInfo.Status) async {
        self.productID = status.transaction.productID

        switch status.state {
        case .subscribed:
            self.state = "subscribed"
        case .expired:
            self.state = "expired"
        case .inGracePeriod:
            self.state = "inGracePeriod"
        case .inBillingRetryPeriod:
            self.state = "inBillingRetryPeriod"
        case .revoked:
            self.state = "revoked"
        @unknown default:
            self.state = "unknown"
        }

        self.renewalInfo = status.renewalInfo.map { RenewalInfo(from: $0) }
        self.transaction = TransactionInfo(from: status.transaction)
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "productID": productID,
            "state": state
        ]

        if let renewal = renewalInfo {
            dict["renewalInfo"] = renewal.toDictionary()
        }

        if let trans = transaction {
            dict["transaction"] = trans.toDictionary()
        }

        return dict
    }
}

// MARK: - Renewal Information

@available(iOS 15.0, *)
struct RenewalInfo: Codable {
    let willAutoRenew: Bool
    let expirationReason: String?
    let gracePeriodExpirationDate: Date?
    let offerID: String?
    let offerType: String?

    init(from renewalInfo: Product.SubscriptionInfo.RenewalInfo) {
        self.willAutoRenew = renewalInfo.willAutoRenew
        self.gracePeriodExpirationDate = renewalInfo.gracePeriodExpirationDate
        self.offerID = renewalInfo.offerID

        if let reason = renewalInfo.expirationReason {
            switch reason {
            case .autoRenewDisabled:
                self.expirationReason = "autoRenewDisabled"
            case .billingError:
                self.expirationReason = "billingError"
            case .didNotConsentToPriceIncrease:
                self.expirationReason = "didNotConsentToPriceIncrease"
            case .productUnavailable:
                self.expirationReason = "productUnavailable"
            @unknown default:
                self.expirationReason = "unknown"
            }
        } else {
            self.expirationReason = nil
        }

        if let offer = renewalInfo.offerType {
            switch offer {
            case .introductory:
                self.offerType = "introductory"
            case .promotional:
                self.offerType = "promotional"
            @unknown default:
                self.offerType = "unknown"
            }
        } else {
            self.offerType = nil
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "willAutoRenew": willAutoRenew
        ]

        if let reason = expirationReason {
            dict["expirationReason"] = reason
        }

        if let graceDate = gracePeriodExpirationDate {
            dict["gracePeriodExpirationDate"] = graceDate.timeIntervalSince1970 * 1000
        }

        if let offer = offerID {
            dict["offerID"] = offer
        }

        if let offerT = offerType {
            dict["offerType"] = offerT
        }

        return dict
    }
}

// MARK: - Error Codes

enum PurchaseError: Int {
    case unknown = 0
    case userCancelled = 1
    case invalidProductID = 2
    case networkError = 3
    case invalidPurchase = 4
    case productNotAvailable = 5
    case purchaseNotAllowed = 6
    case verificationFailed = 7
    case pending = 8
    case receiptValidationFailed = 9

    var description: String {
        switch self {
        case .unknown:
            return "An unknown error occurred"
        case .userCancelled:
            return "User cancelled the purchase"
        case .invalidProductID:
            return "Invalid product ID"
        case .networkError:
            return "Network error occurred"
        case .invalidPurchase:
            return "Invalid purchase"
        case .productNotAvailable:
            return "Product not available"
        case .purchaseNotAllowed:
            return "Purchase not allowed"
        case .verificationFailed:
            return "Transaction verification failed"
        case .pending:
            return "Purchase is pending"
        case .receiptValidationFailed:
            return "Receipt validation failed"
        }
    }
}

// MARK: - Extensions

@available(iOS 15.0, *)
extension Product.SubscriptionPeriod.Unit {
    var description: String {
        switch self {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        @unknown default:
            return "unknown"
        }
    }
}
