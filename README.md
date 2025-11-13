# Cordova iOS In-App Purchase Plugin

A production-grade Cordova plugin for iOS In-App Purchases and Subscriptions using Apple's StoreKit 2 framework.

## Features

- **StoreKit 2** - Modern async/await API for iOS 15+
- **All Product Types** - Consumables, non-consumables, auto-renewable subscriptions, and non-renewing subscriptions
- **Automatic Transaction Handling** - Automatic verification and finishing of transactions
- **Subscription Management** - Full support for subscription status, renewal info, and promotional offers
- **Receipt Validation** - Local receipt access and refresh capabilities
- **Family Sharing** - Support for family-shared purchases
- **Refund Requests** - In-app refund request support
- **TypeScript Support** - Full type definitions included
- **Event-Driven** - Real-time transaction update notifications

## Requirements

- Cordova iOS 6.0.0 or higher
- iOS 15.0 or higher (StoreKit 2)
- Xcode 13 or higher

## Installation

```bash
cordova plugin add cordova-plugin-ios-purchase
```

Or install from local directory:

```bash
cordova plugin add /path/to/cordova-plugin-ios-purchase
```

## Setup

### 1. App Store Connect Configuration

Before using this plugin, you must:

1. Create your app in App Store Connect
2. Create and configure your in-app purchase products
3. Set up a Sandbox Tester account for testing
4. Configure your app's Paid Applications Agreement

### 2. Xcode Configuration

1. Enable the **In-App Purchase** capability in your Xcode project
2. Ensure your Bundle ID matches the one in App Store Connect

### 3. StoreKit Configuration File (Optional for Testing)

For local testing in Xcode, create a StoreKit Configuration File:

1. In Xcode: File > New > File > StoreKit Configuration File
2. Add your product IDs and configurations
3. Select this configuration file in your scheme settings

## Usage

### Basic Example

```javascript
document.addEventListener('deviceready', async function() {
    try {
        // Fetch products
        const products = await iOSPurchase.getProducts([
            'com.yourapp.product1',
            'com.yourapp.subscription1'
        ]);
        
        console.log('Products:', products);
        
        // Purchase a product
        const transaction = await iOSPurchase.purchase('com.yourapp.product1');
        console.log('Purchase successful:', transaction);
        
        // Check if a product is purchased
        const isPurchased = await iOSPurchase.isPurchased('com.yourapp.product1');
        console.log('Is purchased:', isPurchased);
        
    } catch (error) {
        console.error('Error:', error);
        
        if (error.code === iOSPurchase.ErrorCode.USER_CANCELLED) {
            console.log('User cancelled the purchase');
        }
    }
});
```

### TypeScript Example

```typescript
import iOSPurchase, { Product, Transaction, PurchaseError } from 'cordova-plugin-ios-purchase';

async function loadProducts() {
    try {
        const products: Product[] = await iOSPurchase.getProducts([
            'com.yourapp.product1',
            'com.yourapp.subscription1'
        ]);
        
        products.forEach(product => {
            console.log(`${product.displayName}: ${product.priceFormatted}`);
        });
    } catch (error) {
        console.error('Failed to load products:', error);
    }
}

async function purchaseProduct(productId: string) {
    try {
        const transaction: Transaction = await iOSPurchase.purchase(productId);
        console.log('Purchase successful!', transaction);
        return transaction;
    } catch (error) {
        const purchaseError = error as PurchaseError;
        
        switch (purchaseError.code) {
            case iOSPurchase.ErrorCode.USER_CANCELLED:
                console.log('User cancelled');
                break;
            case iOSPurchase.ErrorCode.NETWORK_ERROR:
                console.log('Network error');
                break;
            default:
                console.error('Purchase failed:', purchaseError.message);
        }
        throw error;
    }
}
```

## API Reference

### Product Management

#### `getProducts(productIDs: string[]): Promise<Product[]>`

Fetch products from the App Store.

```javascript
const products = await iOSPurchase.getProducts([
    'com.yourapp.consumable1',
    'com.yourapp.subscription1'
]);

products.forEach(product => {
    console.log(product.displayName, product.priceFormatted);
});
```

**Product Object:**
```typescript
{
    id: string;                    // Product identifier
    displayName: string;           // Product display name
    description: string;           // Product description
    price: number;                 // Price as number
    priceFormatted: string;        // Formatted price (e.g., "$9.99")
    currencyCode: string;          // Currency code (e.g., "USD")
    type: ProductType;             // Product type
    subscriptionInfo?: {           // Only for subscriptions
        groupID: string;
        subscriptionPeriod: string;
        introductoryOffer?: OfferInfo;
        promotionalOffers: OfferInfo[];
    }
}
```

### Purchase Management

#### `purchase(productID: string, offerID?: string): Promise<Transaction>`

Purchase a product. Optionally provide an offer ID for promotional subscription offers.

```javascript
// Regular purchase
const transaction = await iOSPurchase.purchase('com.yourapp.product1');

// Purchase with promotional offer
const transaction = await iOSPurchase.purchase(
    'com.yourapp.subscription1',
    'promo_offer_id'
);
```

#### `restorePurchases(): Promise<Transaction[]>`

Restore previous purchases. Required for non-consumable products and subscriptions.

```javascript
const restoredTransactions = await iOSPurchase.restorePurchases();
console.log('Restored', restoredTransactions.length, 'purchases');
```

#### `getCurrentEntitlements(): Promise<Transaction[]>`

Get all current active entitlements (purchases that haven't expired or been revoked).

```javascript
const entitlements = await iOSPurchase.getCurrentEntitlements();

entitlements.forEach(transaction => {
    console.log('Active:', transaction.productID);
});
```

#### `isPurchased(productID: string): Promise<boolean>`

Check if a specific product is currently purchased.

```javascript
const hasPremium = await iOSPurchase.isPurchased('com.yourapp.premium');

if (hasPremium) {
    // Enable premium features
}
```

### Subscription Management

#### `getSubscriptionStatus(productID: string): Promise<SubscriptionStatus | null>`

Get detailed subscription status for a product.

```javascript
const status = await iOSPurchase.getSubscriptionStatus('com.yourapp.subscription1');

if (status) {
    console.log('State:', status.state);
    console.log('Will auto-renew:', status.renewalInfo?.willAutoRenew);
    
    if (status.state === 'subscribed') {
        // User has active subscription
    } else if (status.state === 'inGracePeriod') {
        // Subscription in grace period (billing issue)
        console.log('Payment issue - update payment method');
    }
}
```

**Subscription States:**
- `subscribed` - Active subscription
- `expired` - Subscription expired
- `inGracePeriod` - In grace period (billing issue, still has access)
- `inBillingRetryPeriod` - Billing retry (user lost access, Apple trying to charge)
- `revoked` - Subscription was refunded

#### `getSubscriptionStatuses(groupID: string): Promise<SubscriptionStatus[]>`

Get all subscription statuses for a subscription group.

```javascript
const statuses = await iOSPurchase.getSubscriptionStatuses('premium_group');

statuses.forEach(status => {
    console.log(`${status.productID}: ${status.state}`);
});
```

### Receipt Management

#### `getReceipt(): Promise<Receipt>`

Get the App Store receipt data (base64 encoded).

```javascript
const receipt = await iOSPurchase.getReceipt();

if (receipt.hasReceipt) {
    // Send receipt.receiptData to your server for validation
    await validateOnServer(receipt.receiptData);
}
```

#### `refreshReceipt(): Promise<void>`

Refresh the App Store receipt. This will prompt the user to authenticate.

```javascript
try {
    await iOSPurchase.refreshReceipt();
    console.log('Receipt refreshed');
} catch (error) {
    console.error('Failed to refresh receipt:', error);
}
```

### Refund Management

#### `beginRefundRequest(transactionID: string): Promise<RefundStatus>`

Initiate an in-app refund request for a transaction.

```javascript
const status = await iOSPurchase.beginRefundRequest(transaction.id);

if (status === 'success') {
    console.log('Refund initiated');
} else if (status === 'userCancelled') {
    console.log('User cancelled refund request');
}
```

### Event Listeners

#### `onTransactionUpdate(callback: (transaction: Transaction) => void): () => void`

Listen for transaction updates (automatic renewals, refunds, family sharing changes).

```javascript
// Add listener
const removeListener = iOSPurchase.onTransactionUpdate((transaction) => {
    console.log('Transaction updated:', transaction);
    
    // Update UI or unlock content based on transaction
    if (transaction.revocationDate) {
        // Transaction was refunded - revoke access
        console.log('Transaction refunded:', transaction.productID);
    } else {
        // New purchase or renewal
        console.log('New transaction:', transaction.productID);
    }
});

// Remove listener when done
removeListener();
```

## Error Handling

The plugin provides detailed error codes for proper error handling:

```javascript
try {
    await iOSPurchase.purchase(productId);
} catch (error) {
    switch (error.code) {
        case iOSPurchase.ErrorCode.USER_CANCELLED:
            // User cancelled - no action needed
            break;
            
        case iOSPurchase.ErrorCode.NETWORK_ERROR:
            // Network issue - retry later
            showRetryOption();
            break;
            
        case iOSPurchase.ErrorCode.PURCHASE_NOT_ALLOWED:
            // In-app purchases disabled in settings
            showSettingsMessage();
            break;
            
        case iOSPurchase.ErrorCode.INVALID_PRODUCT_ID:
            // Product not found in App Store Connect
            logError('Invalid product configuration');
            break;
            
        case iOSPurchase.ErrorCode.PENDING:
            // Purchase pending (Ask to Buy, parental approval)
            showPendingMessage();
            break;
            
        default:
            // Other errors
            showGenericError(error.message);
    }
}
```

**Error Codes:**
- `UNKNOWN (0)` - Unknown error
- `USER_CANCELLED (1)` - User cancelled the purchase
- `INVALID_PRODUCT_ID (2)` - Invalid product ID
- `NETWORK_ERROR (3)` - Network error
- `INVALID_PURCHASE (4)` - Invalid purchase
- `PRODUCT_NOT_AVAILABLE (5)` - Product not available
- `PURCHASE_NOT_ALLOWED (6)` - Purchases not allowed
- `VERIFICATION_FAILED (7)` - Transaction verification failed
- `PENDING (8)` - Purchase pending approval
- `RECEIPT_VALIDATION_FAILED (9)` - Receipt validation failed

## Best Practices

### 1. Transaction Verification

Always use server-side receipt validation for production apps:

```javascript
async function verifyPurchase(transaction) {
    // Get receipt
    const receipt = await iOSPurchase.getReceipt();
    
    // Send to your server
    const response = await fetch('https://yourserver.com/verify-receipt', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            receipt: receipt.receiptData,
            transactionId: transaction.id
        })
    });
    
    const result = await response.json();
    
    if (result.valid) {
        // Unlock content
        unlockFeature(transaction.productID);
    }
}
```

### 2. Handle Transaction Updates

Always listen for transaction updates to handle:
- Automatic subscription renewals
- Refunds
- Family sharing changes
- Pending purchases completing

```javascript
iOSPurchase.onTransactionUpdate(async (transaction) => {
    // Verify and process the transaction
    await verifyPurchase(transaction);
});
```

### 3. Restore Purchases

Provide a "Restore Purchases" button for users who reinstall your app:

```javascript
async function handleRestorePurchases() {
    try {
        const transactions = await iOSPurchase.restorePurchases();
        
        if (transactions.length > 0) {
            // Process restored purchases
            for (const transaction of transactions) {
                await verifyPurchase(transaction);
            }
            showMessage('Purchases restored successfully');
        } else {
            showMessage('No purchases to restore');
        }
    } catch (error) {
        showError('Failed to restore purchases');
    }
}
```

### 4. Handle Subscription States

Monitor subscription states and provide appropriate user messaging:

```javascript
async function checkSubscriptionStatus(productId) {
    const status = await iOSPurchase.getSubscriptionStatus(productId);
    
    if (!status) {
        // Not subscribed
        showSubscribeButton();
        return;
    }
    
    switch (status.state) {
        case 'subscribed':
            // Active subscription
            enablePremiumFeatures();
            break;
            
        case 'inGracePeriod':
            // Show warning about payment issue
            enablePremiumFeatures(); // Still has access
            showPaymentWarning();
            break;
            
        case 'inBillingRetryPeriod':
            // Lost access, show strong warning
            disablePremiumFeatures();
            showBillingRetryWarning();
            break;
            
        case 'expired':
            // Subscription expired
            disablePremiumFeatures();
            showResubscribePrompt();
            break;
            
        case 'revoked':
            // Refunded
            disablePremiumFeatures();
            break;
    }
}
```

### 5. Consumable Products

For consumable products, deliver content immediately after purchase:

```javascript
async function purchaseConsumable(productId) {
    try {
        const transaction = await iOSPurchase.purchase(productId);
        
        // Verify with server
        await verifyPurchase(transaction);
        
        // Deliver consumable content (coins, lives, etc.)
        await deliverConsumableContent(productId);
        
    } catch (error) {
        // Handle error
    }
}
```

## Testing

### Sandbox Testing

1. Create a Sandbox Tester account in App Store Connect
2. Sign out of your Apple ID on the test device
3. When testing a purchase, sign in with the sandbox account
4. Use the sandbox environment for all testing

### StoreKit Testing in Xcode

For faster local testing without Sandbox:

1. Create a StoreKit Configuration File in Xcode
2. Add your products to the configuration
3. Run your app with the StoreKit configuration enabled
4. No internet connection or sandbox account required

## Server-Side Validation

For production apps, always validate receipts server-side using Apple's App Store Server API:

### Using App Store Server API (Recommended)

```javascript
// Server-side (Node.js example)
const jwt = require('jsonwebtoken');

async function verifyTransaction(transactionId) {
    // Generate JWT for App Store Server API
    const token = generateJWT(); // Your implementation
    
    // Call App Store Server API
    const response = await fetch(
        `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`,
        {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        }
    );
    
    const data = await response.json();
    return data;
}
```

## Troubleshooting

### Issue: Products not loading

**Solutions:**
- Verify products are approved in App Store Connect
- Check that product IDs match exactly
- Ensure app has In-App Purchase capability enabled
- Wait 2-4 hours after creating products in App Store Connect

### Issue: "Cannot connect to iTunes Store"

**Solutions:**
- Check internet connection
- Verify device is not using VPN
- Try sandbox account if testing
- Ensure App Store Connect agreements are signed

### Issue: Purchase succeeds but content not unlocked

**Solutions:**
- Implement transaction update listener
- Check server-side verification
- Verify transaction is actually completed
- Check for pending transactions

## Security Considerations

1. **Always validate receipts server-side** - Never trust client-side validation alone
2. **Use HTTPS** - All communication with your server must be encrypted
3. **Protect premium content** - Don't ship premium content in the app bundle
4. **Handle refunds** - Monitor transaction updates for revocations
5. **Rate limit** - Implement rate limiting on your validation endpoint

## License

MIT License - see LICENSE file

## Support

For issues and feature requests, please use the [GitHub issue tracker](https://github.com/Shivam-Pancholi/cordova-plugin-ios-purchase/issues).

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

---

Made with ❤️ for the Cordova community
