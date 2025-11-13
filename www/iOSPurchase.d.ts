/**
 * TypeScript definitions for iOS In-App Purchase Plugin
 */

declare module 'cordova-plugin-ios-purchase' {
    
    // MARK: - Product Types

    export interface Product {
        /** Product identifier */
        id: string;
        /** Display name of the product */
        displayName: string;
        /** Product description */
        description: string;
        /** Price as a number */
        price: number;
        /** Formatted price string with currency symbol */
        priceFormatted: string;
        /** Currency code (e.g., 'USD', 'EUR') */
        currencyCode: string;
        /** Product type */
        type: ProductType;
        /** Subscription information (only for subscription products) */
        subscriptionInfo?: SubscriptionInfo;
    }

    export interface SubscriptionInfo {
        /** Subscription group identifier */
        groupID: string;
        /** Subscription period (e.g., '1 month', '1 year') */
        subscriptionPeriod: string;
        /** Introductory offer information */
        introductoryOffer?: OfferInfo;
        /** Promotional offers */
        promotionalOffers: OfferInfo[];
    }

    export interface OfferInfo {
        /** Offer identifier */
        id?: string;
        /** Offer price */
        price: number;
        /** Formatted offer price */
        priceFormatted: string;
        /** Period unit (e.g., 'day', 'week', 'month', 'year') */
        period: string;
        /** Number of periods */
        periodCount: number;
        /** Payment mode */
        paymentMode: PaymentMode;
    }

    // MARK: - Transaction Types

    export interface Transaction {
        /** Transaction identifier */
        id: string;
        /** Product identifier */
        productID: string;
        /** Purchase date (timestamp in milliseconds) */
        purchaseDate: number;
        /** Expiration date for subscriptions (timestamp in milliseconds) */
        expirationDate?: number;
        /** Revocation date if refunded (timestamp in milliseconds) */
        revocationDate?: number;
        /** Whether the subscription was upgraded */
        isUpgraded: boolean;
        /** Promotional offer ID used */
        offerID?: string;
        /** Type of offer used */
        offerType?: OfferType;
        /** Transaction environment */
        environment: Environment;
        /** Ownership type */
        ownershipType: OwnershipType;
    }

    // MARK: - Subscription Status

    export interface SubscriptionStatus {
        /** Product identifier */
        productID: string;
        /** Current subscription state */
        state: SubscriptionState;
        /** Renewal information */
        renewalInfo?: RenewalInfo;
        /** Transaction information */
        transaction?: Transaction;
    }

    export interface RenewalInfo {
        /** Whether auto-renewal is enabled */
        willAutoRenew: boolean;
        /** Reason for expiration */
        expirationReason?: ExpirationReason;
        /** Grace period expiration date (timestamp in milliseconds) */
        gracePeriodExpirationDate?: number;
        /** Promotional offer ID */
        offerID?: string;
        /** Type of offer */
        offerType?: OfferType;
    }

    // MARK: - Receipt

    export interface Receipt {
        /** Base64 encoded receipt data */
        receiptData?: string;
        /** Whether receipt exists */
        hasReceipt: boolean;
    }

    // MARK: - Enums

    export type ProductType =
        | 'consumable'
        | 'non-consumable'
        | 'auto-renewable-subscription'
        | 'non-renewing-subscription';

    export type PaymentMode =
        | 'payAsYouGo'
        | 'payUpFront'
        | 'freeTrial';

    export type OfferType =
        | 'introductory'
        | 'promotional';

    export type Environment =
        | 'production'
        | 'sandbox'
        | 'xcode';

    export type OwnershipType =
        | 'purchased'
        | 'familyShared';

    export type SubscriptionState =
        | 'subscribed'
        | 'expired'
        | 'inGracePeriod'
        | 'inBillingRetryPeriod'
        | 'revoked';

    export type ExpirationReason =
        | 'autoRenewDisabled'
        | 'billingError'
        | 'didNotConsentToPriceIncrease'
        | 'productUnavailable';

    export type RefundStatus =
        | 'success'
        | 'userCancelled'
        | 'unknown';

    // MARK: - Error

    export interface PurchaseError extends Error {
        code: ErrorCode;
        message: string;
    }

    export enum ErrorCode {
        UNKNOWN = 0,
        USER_CANCELLED = 1,
        INVALID_PRODUCT_ID = 2,
        NETWORK_ERROR = 3,
        INVALID_PURCHASE = 4,
        PRODUCT_NOT_AVAILABLE = 5,
        PURCHASE_NOT_ALLOWED = 6,
        VERIFICATION_FAILED = 7,
        PENDING = 8,
        RECEIPT_VALIDATION_FAILED = 9
    }

    // MARK: - Plugin Interface

    export interface iOSPurchasePlugin {
        /**
         * Fetch products from the App Store
         * @param productIDs Array of product identifiers
         * @returns Promise resolving to array of product information
         */
        getProducts(productIDs: string[]): Promise<Product[]>;

        /**
         * Purchase a product
         * @param productID Product identifier
         * @param offerID Optional promotional offer ID for subscriptions
         * @returns Promise resolving to transaction information
         */
        purchase(productID: string, offerID?: string): Promise<Transaction>;

        /**
         * Restore previous purchases
         * @returns Promise resolving to array of restored transactions
         */
        restorePurchases(): Promise<Transaction[]>;

        /**
         * Get current entitlements (active purchases)
         * @returns Promise resolving to array of current entitlements
         */
        getCurrentEntitlements(): Promise<Transaction[]>;

        /**
         * Check if a product is purchased
         * @param productID Product identifier
         * @returns Promise resolving to true if purchased
         */
        isPurchased(productID: string): Promise<boolean>;

        /**
         * Get subscription status for a product
         * @param productID Product identifier
         * @returns Promise resolving to subscription status or null
         */
        getSubscriptionStatus(productID: string): Promise<SubscriptionStatus | null>;

        /**
         * Get all subscription statuses for a subscription group
         * @param groupID Subscription group identifier
         * @returns Promise resolving to array of subscription statuses
         */
        getSubscriptionStatuses(groupID: string): Promise<SubscriptionStatus[]>;

        /**
         * Get App Store receipt data
         * @returns Promise resolving to receipt information
         */
        getReceipt(): Promise<Receipt>;

        /**
         * Refresh the App Store receipt
         * This will prompt the user to authenticate if needed
         * @returns Promise that resolves when refresh is complete
         */
        refreshReceipt(): Promise<void>;

        /**
         * Begin a refund request for a transaction
         * @param transactionID Transaction identifier
         * @returns Promise resolving to refund status
         */
        beginRefundRequest(transactionID: string): Promise<RefundStatus>;

        /**
         * Add listener for transaction updates
         * @param callback Callback function to handle transaction updates
         * @returns Function to remove the listener
         */
        onTransactionUpdate(callback: (transaction: Transaction) => void): () => void;

        /** Error codes */
        readonly ErrorCode: typeof ErrorCode;

        /** Product types */
        readonly ProductType: {
            CONSUMABLE: 'consumable';
            NON_CONSUMABLE: 'non-consumable';
            AUTO_RENEWABLE_SUBSCRIPTION: 'auto-renewable-subscription';
            NON_RENEWING_SUBSCRIPTION: 'non-renewing-subscription';
        };

        /** Subscription states */
        readonly SubscriptionState: {
            SUBSCRIBED: 'subscribed';
            EXPIRED: 'expired';
            IN_GRACE_PERIOD: 'inGracePeriod';
            IN_BILLING_RETRY: 'inBillingRetryPeriod';
            REVOKED: 'revoked';
        };

        /** Transaction environments */
        readonly Environment: {
            PRODUCTION: 'production';
            SANDBOX: 'sandbox';
            XCODE: 'xcode';
        };
    }

    const iOSPurchase: iOSPurchasePlugin;
    export default iOSPurchase;
}

// Global declaration for Cordova
declare global {
    interface Window {
        iOSPurchase: import('cordova-plugin-ios-purchase').iOSPurchasePlugin;
    }
}
