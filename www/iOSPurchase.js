/**
 * iOS In-App Purchase Plugin
 * Production-grade Cordova plugin for iOS In-App Purchases and Subscriptions
 */

const exec = require('cordova/exec');

const iOSPurchase = {

    // MARK: - Product Management

    /**
     * Fetch products from the App Store
     * @param {string[]} productIDs - Array of product identifiers
     * @returns {Promise<Product[]>} Array of product information
     */
    getProducts: function(productIDs) {
        return new Promise((resolve, reject) => {
            if (!Array.isArray(productIDs) || productIDs.length === 0) {
                reject(new Error('Product IDs must be a non-empty array'));
                return;
            }

            exec(resolve, reject, 'iOSPurchase', 'getProducts', [productIDs]);
        });
    },

    // MARK: - Purchase Management

    /**
     * Purchase a product
     * @param {string} productID - Product identifier
     * @param {string} [offerID] - Optional promotional offer ID for subscriptions
     * @returns {Promise<Transaction>} Transaction information
     */
    purchase: function(productID, offerID) {
        return new Promise((resolve, reject) => {
            if (!productID || typeof productID !== 'string') {
                reject(new Error('Product ID must be a non-empty string'));
                return;
            }

            const args = [productID];
            if (offerID) {
                args.push(offerID);
            }

            exec(
                (transaction) => {
                    resolve(transaction);
                },
                (error) => {
                    // Format error for better handling
                    if (typeof error === 'object') {
                        const err = new Error(error.message || 'Purchase failed');
                        err.code = error.code;
                        reject(err);
                    } else {
                        reject(new Error(error));
                    }
                },
                'iOSPurchase',
                'purchase',
                args
            );
        });
    },

    /**
     * Restore previous purchases
     * @returns {Promise<Transaction[]>} Array of restored transactions
     */
    restorePurchases: function() {
        return new Promise((resolve, reject) => {
            exec(resolve, reject, 'iOSPurchase', 'restorePurchases', []);
        });
    },

    /**
     * Get current entitlements (active purchases)
     * @returns {Promise<Transaction[]>} Array of current entitlements
     */
    getCurrentEntitlements: function() {
        return new Promise((resolve, reject) => {
            exec(resolve, reject, 'iOSPurchase', 'getCurrentEntitlements', []);
        });
    },

    /**
     * Check if a product is purchased
     * @param {string} productID - Product identifier
     * @returns {Promise<boolean>} True if purchased
     */
    isPurchased: function(productID) {
        return new Promise((resolve, reject) => {
            if (!productID || typeof productID !== 'string') {
                reject(new Error('Product ID must be a non-empty string'));
                return;
            }

            exec(resolve, reject, 'iOSPurchase', 'isPurchased', [productID]);
        });
    },

    // MARK: - Subscription Management

    /**
     * Get subscription status for a product
     * @param {string} productID - Product identifier
     * @returns {Promise<SubscriptionStatus|null>} Subscription status or null if not a subscription
     */
    getSubscriptionStatus: function(productID) {
        return new Promise((resolve, reject) => {
            if (!productID || typeof productID !== 'string') {
                reject(new Error('Product ID must be a non-empty string'));
                return;
            }

            exec(resolve, reject, 'iOSPurchase', 'getSubscriptionStatus', [productID]);
        });
    },

    /**
     * Get all subscription statuses for a subscription group
     * @param {string} groupID - Subscription group identifier
     * @returns {Promise<SubscriptionStatus[]>} Array of subscription statuses
     */
    getSubscriptionStatuses: function(groupID) {
        return new Promise((resolve, reject) => {
            if (!groupID || typeof groupID !== 'string') {
                reject(new Error('Group ID must be a non-empty string'));
                return;
            }

            exec(resolve, reject, 'iOSPurchase', 'getSubscriptionStatuses', [groupID]);
        });
    },

    // MARK: - Receipt Management

    /**
     * Get App Store receipt data
     * @returns {Promise<Receipt>} Receipt information
     */
    getReceipt: function() {
        return new Promise((resolve, reject) => {
            exec(resolve, reject, 'iOSPurchase', 'getReceipt', []);
        });
    },

    /**
     * Refresh the App Store receipt
     * This will prompt the user to authenticate if needed
     * @returns {Promise<void>}
     */
    refreshReceipt: function() {
        return new Promise((resolve, reject) => {
            exec(resolve, reject, 'iOSPurchase', 'refreshReceipt', []);
        });
    },

    // MARK: - Refund Management

    /**
     * Begin a refund request for a transaction
     * @param {string} transactionID - Transaction identifier
     * @returns {Promise<string>} Refund status ('success', 'userCancelled', or 'unknown')
     */
    beginRefundRequest: function(transactionID) {
        return new Promise((resolve, reject) => {
            if (!transactionID) {
                reject(new Error('Transaction ID is required'));
                return;
            }

            exec(resolve, reject, 'iOSPurchase', 'beginRefundRequest', [String(transactionID)]);
        });
    },

    // MARK: - Event Listeners

    /**
     * Add listener for transaction updates
     * @param {Function} callback - Callback function to handle transaction updates
     * @returns {Function} Function to remove the listener
     */
    onTransactionUpdate: function(callback) {
        if (typeof callback !== 'function') {
            throw new Error('Callback must be a function');
        }

        const listener = function(event) {
            callback(event.detail || event);
        };

        document.addEventListener('transactionUpdate', listener);

        // Return function to remove listener
        return function() {
            document.removeEventListener('transactionUpdate', listener);
        };
    },

    // MARK: - Error Codes

    /**
     * Error codes returned by the plugin
     */
    ErrorCode: {
        UNKNOWN: 0,
        USER_CANCELLED: 1,
        INVALID_PRODUCT_ID: 2,
        NETWORK_ERROR: 3,
        INVALID_PURCHASE: 4,
        PRODUCT_NOT_AVAILABLE: 5,
        PURCHASE_NOT_ALLOWED: 6,
        VERIFICATION_FAILED: 7,
        PENDING: 8,
        RECEIPT_VALIDATION_FAILED: 9
    },

    /**
     * Product types
     */
    ProductType: {
        CONSUMABLE: 'consumable',
        NON_CONSUMABLE: 'non-consumable',
        AUTO_RENEWABLE_SUBSCRIPTION: 'auto-renewable-subscription',
        NON_RENEWING_SUBSCRIPTION: 'non-renewing-subscription'
    },

    /**
     * Subscription states
     */
    SubscriptionState: {
        SUBSCRIBED: 'subscribed',
        EXPIRED: 'expired',
        IN_GRACE_PERIOD: 'inGracePeriod',
        IN_BILLING_RETRY: 'inBillingRetryPeriod',
        REVOKED: 'revoked'
    },

    /**
     * Transaction environments
     */
    Environment: {
        PRODUCTION: 'production',
        SANDBOX: 'sandbox',
        XCODE: 'xcode'
    }
};

module.exports = iOSPurchase;
