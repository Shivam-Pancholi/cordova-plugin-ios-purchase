# Best Practices for iOS In-App Purchases

This guide covers production-ready best practices for implementing in-app purchases in your Cordova iOS app.

## Table of Contents

1. [Security](#security)
2. [Receipt Validation](#receipt-validation)
3. [Transaction Handling](#transaction-handling)
4. [Subscription Management](#subscription-management)
5. [Error Handling](#error-handling)
6. [Testing](#testing)
7. [User Experience](#user-experience)
8. [Performance](#performance)

## Security

### 1. Always Validate Server-Side

**NEVER** trust client-side validation alone. Always verify purchases on your server.

```javascript
// ❌ BAD: Client-side only
async function handlePurchase(transaction) {
    // Just unlock content without server verification
    unlockContent(transaction.productID);
}

// ✅ GOOD: Server-side verification
async function handlePurchase(transaction) {
    const isValid = await verifyWithServer(transaction);
    if (isValid) {
        unlockContent(transaction.productID);
    }
}
```

### 2. Use HTTPS for All Communication

All API calls to your validation server must use HTTPS.

```javascript
// ❌ BAD
const API_URL = 'http://yourserver.com/verify';

// ✅ GOOD
const API_URL = 'https://yourserver.com/verify';
```

### 3. Protect Premium Content

Don't ship premium content in your app bundle where it can be easily accessed.

```javascript
// ✅ GOOD: Download content after verification
async function unlockPremiumContent() {
    const hasAccess = await verifyPurchase();
    if (hasAccess) {
        await downloadPremiumContent();
    }
}
```

### 4. Rate Limit Validation Requests

Implement rate limiting on your server to prevent abuse.

```javascript
// Server-side (Node.js example)
const rateLimit = require('express-rate-limit');

const validationLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each user to 100 requests per windowMs
});

app.post('/verify-receipt', validationLimiter, async (req, res) => {
    // Validation logic
});
```

## Receipt Validation

### 1. Use App Store Server API (Recommended)

The modern approach is to use Apple's App Store Server API with JWS tokens.

```javascript
// Client-side: Get receipt
const receipt = await iOSPurchase.getReceipt();

// Send to your server
await fetch('https://yourserver.com/verify', {
    method: 'POST',
    body: JSON.stringify({
        receiptData: receipt.receiptData,
        transactionId: transaction.id
    })
});
```

```javascript
// Server-side: Verify using App Store Server API
async function verifyWithAppStoreAPI(transactionId) {
    const jwt = generateJWT(); // Your JWT generation
    
    const response = await fetch(
        `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`,
        {
            headers: {
                'Authorization': `Bearer ${jwt}`
            }
        }
    );
    
    return await response.json();
}
```

### 2. Cache Validation Results

Cache validation results to avoid unnecessary API calls.

```javascript
const validationCache = new Map();

async function verifyPurchase(transactionId) {
    // Check cache first
    if (validationCache.has(transactionId)) {
        return validationCache.get(transactionId);
    }
    
    // Verify with server
    const result = await verifyWithServer(transactionId);
    
    // Cache for 5 minutes
    validationCache.set(transactionId, result);
    setTimeout(() => validationCache.delete(transactionId), 5 * 60 * 1000);
    
    return result;
}
```

### 3. Handle Validation Failures Gracefully

Don't block users if validation temporarily fails.

```javascript
async function verifyPurchase(transaction) {
    try {
        return await verifyWithServer(transaction);
    } catch (error) {
        // Log error for monitoring
        logError('Validation failed', error);
        
        // Allow temporary offline access for network errors
        if (error.code === 'NETWORK_ERROR') {
            return checkLocalCache(transaction);
        }
        
        return false;
    }
}
```

## Transaction Handling

### 1. Always Listen for Transaction Updates

Set up transaction listeners on app start to catch renewals, refunds, and family sharing.

```javascript
document.addEventListener('deviceready', () => {
    // Set up listener immediately
    iOSPurchase.onTransactionUpdate(handleTransactionUpdate);
    
    // Then load your app
    initializeApp();
});
```

### 2. Handle All Transaction States

Be prepared for all possible transaction states.

```javascript
async function handleTransactionUpdate(transaction) {
    if (transaction.revocationDate) {
        // Refund - revoke access
        revokeAccess(transaction.productID);
    } else if (transaction.isUpgraded) {
        // Subscription upgraded - may need to adjust features
        handleUpgrade(transaction);
    } else {
        // New purchase or renewal
        grantAccess(transaction.productID);
    }
}
```

### 3. Finish Transactions Properly

The plugin automatically finishes transactions after verification. Don't manually finish unless you have a specific reason.

### 4. Store Transaction Information

Keep a local record of transactions for offline access.

```javascript
async function recordTransaction(transaction) {
    const transactions = JSON.parse(localStorage.getItem('transactions') || '[]');
    transactions.push({
        id: transaction.id,
        productID: transaction.productID,
        purchaseDate: transaction.purchaseDate,
        verified: true
    });
    localStorage.setItem('transactions', JSON.stringify(transactions));
}
```

## Subscription Management

### 1. Check Status on App Start

Always check subscription status when the app starts.

```javascript
document.addEventListener('deviceready', async () => {
    await checkSubscriptionStatus();
    initializeApp();
});
```

### 2. Handle Grace Period Properly

During grace period, users still have access but should be notified about payment issues.

```javascript
async function checkSubscriptionStatus() {
    const status = await iOSPurchase.getSubscriptionStatus(SUBSCRIPTION_ID);
    
    if (status.state === 'inGracePeriod') {
        // User still has access
        enableFeatures();
        
        // But show warning
        showPaymentWarning({
            message: 'Please update your payment method',
            action: () => openSubscriptionSettings()
        });
    }
}
```

### 3. Monitor Billing Retry Period

During billing retry, users have lost access and need immediate action.

```javascript
if (status.state === 'inBillingRetryPeriod') {
    // No access during billing retry
    disableFeatures();
    
    // Show urgent message
    showBillingRetryAlert({
        title: 'Subscription Payment Failed',
        message: 'Update your payment method to continue',
        action: () => openSubscriptionSettings()
    });
}
```

### 4. Handle Subscription Changes

Detect and handle upgrades, downgrades, and cancellations.

```javascript
function handleSubscriptionChange(oldStatus, newStatus) {
    if (newStatus.state === 'subscribed' && oldStatus.productID !== newStatus.productID) {
        // User changed subscription tier
        adjustFeatures(newStatus.productID);
    } else if (!newStatus.renewalInfo.willAutoRenew) {
        // User cancelled - subscription will expire at end of period
        showCancellationMessage(newStatus.transaction.expirationDate);
    }
}
```

## Error Handling

### 1. Provide Specific Error Messages

Don't show generic errors - be specific about the problem.

```javascript
function getErrorMessage(error) {
    switch (error.code) {
        case iOSPurchase.ErrorCode.USER_CANCELLED:
            return null; // Don't show message for user cancellation
            
        case iOSPurchase.ErrorCode.NETWORK_ERROR:
            return 'Network connection error. Please check your internet and try again.';
            
        case iOSPurchase.ErrorCode.PURCHASE_NOT_ALLOWED:
            return 'Purchases are disabled. Please check Settings > Screen Time > Content Restrictions.';
            
        case iOSPurchase.ErrorCode.PENDING:
            return 'Purchase is pending approval.';
            
        default:
            return 'Purchase failed. Please try again or contact support.';
    }
}
```

### 2. Log Errors for Monitoring

Implement error logging to track issues in production.

```javascript
async function logError(context, error) {
    const errorLog = {
        timestamp: Date.now(),
        context: context,
        code: error.code,
        message: error.message,
        stack: error.stack
    };
    
    // Send to your analytics/logging service
    await sendToAnalytics('iap_error', errorLog);
}
```

### 3. Implement Retry Logic

Automatically retry failed operations when appropriate.

```javascript
async function purchaseWithRetry(productId, maxRetries = 2) {
    for (let i = 0; i <= maxRetries; i++) {
        try {
            return await iOSPurchase.purchase(productId);
        } catch (error) {
            // Don't retry user cancellations
            if (error.code === iOSPurchase.ErrorCode.USER_CANCELLED) {
                throw error;
            }
            
            // Retry on network errors
            if (error.code === iOSPurchase.ErrorCode.NETWORK_ERROR && i < maxRetries) {
                await delay(2000 * (i + 1)); // Exponential backoff
                continue;
            }
            
            throw error;
        }
    }
}
```

## Testing

### 1. Test in Sandbox Environment

Always test thoroughly in Apple's Sandbox environment.

```javascript
// Create separate sandbox tester accounts for different scenarios:
// - First-time purchases
// - Restore purchases
// - Subscription renewals
// - Subscription cancellations
```

### 2. Test All Product Types

Test each product type separately:
- Consumables
- Non-consumables
- Auto-renewable subscriptions
- Non-renewing subscriptions

### 3. Test Edge Cases

Don't forget to test:
- Poor network conditions
- App backgrounding during purchase
- Multiple rapid purchases
- Restore after uninstall/reinstall
- Family sharing scenarios
- Refunds

### 4. Use StoreKit Testing

For faster iteration, use StoreKit Testing in Xcode.

```bash
# Create a StoreKit Configuration File
# File > New > File > StoreKit Configuration File

# Add your products to the config file
# Edit Scheme > Run > Options > StoreKit Configuration
```

## User Experience

### 1. Show Loading States

Always show loading indicators during operations.

```javascript
async function purchase(productId) {
    showLoading('Processing purchase...');
    try {
        const transaction = await iOSPurchase.purchase(productId);
        // Success handling
    } finally {
        hideLoading();
    }
}
```

### 2. Provide Restore Purchases Option

Always provide a "Restore Purchases" button for users.

```html
<button onclick="restorePurchases()">Restore Purchases</button>
```

### 3. Show Clear Pricing

Display prices in the user's local currency.

```javascript
function displayProduct(product) {
    // Use priceFormatted, not just price
    return `${product.displayName}: ${product.priceFormatted}`;
}
```

### 4. Explain Subscription Terms

Be transparent about subscription terms.

```javascript
function displaySubscription(product) {
    const info = product.subscriptionInfo;
    return `
        ${product.displayName}
        ${product.priceFormatted} per ${info.subscriptionPeriod}
        Auto-renews unless cancelled
        Cancel anytime in Settings
    `;
}
```

## Performance

### 1. Load Products Asynchronously

Don't block UI while loading products.

```javascript
async function loadProducts() {
    try {
        const products = await iOSPurchase.getProducts(productIds);
        updateUI(products);
    } catch (error) {
        showError(error);
    }
}
```

### 2. Cache Product Information

Cache product info to avoid repeated API calls.

```javascript
let productCache = null;
let cacheTime = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

async function getProducts(productIds) {
    if (productCache && Date.now() - cacheTime < CACHE_DURATION) {
        return productCache;
    }
    
    productCache = await iOSPurchase.getProducts(productIds);
    cacheTime = Date.now();
    
    return productCache;
}
```

### 3. Minimize Network Requests

Batch operations when possible.

```javascript
// ✅ GOOD: Load all products at once
const products = await iOSPurchase.getProducts([
    'product1', 'product2', 'product3'
]);

// ❌ BAD: Load products one by one
for (const id of productIds) {
    await iOSPurchase.getProducts([id]);
}
```

## Compliance

### 1. Follow App Store Review Guidelines

- Clearly describe what users are purchasing
- Use correct product types
- Don't mention other payment methods
- Implement restore purchases

### 2. Handle Refunds Properly

When a refund is issued, revoke access immediately.

```javascript
iOSPurchase.onTransactionUpdate((transaction) => {
    if (transaction.revocationDate) {
        revokeAccess(transaction.productID);
        notifyUserOfRefund();
    }
});
```

### 3. Privacy Considerations

Only collect and store necessary transaction data.

```javascript
// Store minimal information
const transaction = {
    id: transaction.id,
    productID: transaction.productID,
    date: transaction.purchaseDate,
    // Don't store sensitive user information
};
```

## Summary Checklist

- [ ] Server-side receipt validation implemented
- [ ] Transaction update listener set up
- [ ] All error codes handled
- [ ] Restore purchases functionality
- [ ] Subscription status checking
- [ ] Grace period handling
- [ ] Loading indicators
- [ ] Error logging
- [ ] Sandbox testing completed
- [ ] Edge cases tested
- [ ] Clear pricing displayed
- [ ] Privacy compliance verified
