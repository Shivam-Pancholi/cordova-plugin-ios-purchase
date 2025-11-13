//
//  ReceiptValidator.swift
//  iOSPurchasePlugin
//
//  Receipt validation utilities for App Store receipts
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
class ReceiptValidator {

    // MARK: - Receipt Information

    /// Get the app receipt URL
    static func getReceiptURL() -> URL? {
        return Bundle.main.appStoreReceiptURL
    }

    /// Get the receipt data as base64 string
    static func getReceiptData() -> String? {
        guard let receiptURL = getReceiptURL(),
              let receiptData = try? Data(contentsOf: receiptURL) else {
            return nil
        }

        return receiptData.base64EncodedString()
    }

    /// Check if receipt exists
    static func hasReceipt() -> Bool {
        guard let receiptURL = getReceiptURL() else {
            return false
        }

        return FileManager.default.fileExists(atPath: receiptURL.path)
    }

    // MARK: - Receipt Refresh

    /// Refresh the receipt from the App Store
    /// This will prompt the user to authenticate if needed
    static func refreshReceipt() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let request = SKReceiptRefreshRequest()

            // Create delegate to handle the request
            let delegate = ReceiptRefreshDelegate { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }

            request.delegate = delegate
            request.start()

            // Keep delegate alive during request
            objc_setAssociatedObject(request, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - Server-Side Validation

    /// Prepare receipt data for server-side validation
    /// Returns a dictionary with receipt data and transaction information
    static func prepareReceiptForValidation(transaction: TransactionInfo) -> [String: Any] {
        var validationData: [String: Any] = [
            "transactionID": transaction.id,
            "productID": transaction.productID,
            "purchaseDate": transaction.purchaseDate.timeIntervalSince1970 * 1000
        ]

        if let receiptData = getReceiptData() {
            validationData["receiptData"] = receiptData
        }

        if let expirationDate = transaction.expirationDate {
            validationData["expirationDate"] = expirationDate.timeIntervalSince1970 * 1000
        }

        return validationData
    }

    /// Validate receipt with Apple's verifyReceipt endpoint
    /// NOTE: This is for StoreKit 1 receipts. StoreKit 2 uses JWS tokens.
    /// For production, use server-side validation with App Store Server API.
    static func validateReceiptWithApple(receiptData: String, isSandbox: Bool = false) async throws -> [String: Any] {
        let urlString = isSandbox
            ? "https://sandbox.itunes.apple.com/verifyReceipt"
            : "https://buy.itunes.apple.com/verifyReceipt"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ReceiptValidator", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid validation URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "receipt-data": receiptData,
            "exclude-old-transactions": true
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "ReceiptValidator", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Receipt validation failed"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ReceiptValidator", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid response from App Store"])
        }

        // Check status code
        if let status = json["status"] as? Int {
            switch status {
            case 0:
                return json // Valid receipt
            case 21007:
                // Receipt is from sandbox, try sandbox endpoint
                if !isSandbox {
                    return try await validateReceiptWithApple(receiptData: receiptData, isSandbox: true)
                }
                fallthrough
            default:
                throw NSError(domain: "ReceiptValidator", code: status,
                             userInfo: [NSLocalizedDescriptionKey: "Receipt validation failed with status: \(status)"])
            }
        }

        return json
    }

    // MARK: - JWS Token Validation (StoreKit 2)

    /// Extract JWS representation from a transaction
    /// For server-side validation with App Store Server API
    static func getJWSRepresentation(transaction: Transaction) -> String? {
        return transaction.jsonRepresentation
    }

    /// Parse JWS token payload (for debugging - do NOT use for production validation)
    /// Production validation should be done server-side
    static func parseJWSPayload(jws: String) -> [String: Any]? {
        let parts = jws.split(separator: ".")
        guard parts.count == 3 else { return nil }

        let payloadPart = String(parts[1])

        // Add padding if needed
        var base64 = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }
}

// MARK: - Receipt Refresh Delegate

private class ReceiptRefreshDelegate: NSObject, SKRequestDelegate {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    func requestDidFinish(_ request: SKRequest) {
        completion(nil)
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        completion(error)
    }
}
