# Example App

This is a complete example demonstrating all features of the iOS Purchase Plugin.

## Features Demonstrated

-  Loading products from App Store
-  Purchasing consumable products (coins)
-  Purchasing non-consumable products (premium)
-  Subscription management (monthly/yearly)
-  Restoring purchases
-  Checking subscription status
-  Getting receipt data
-  Transaction observer for background updates
-  Error handling
-  UI updates based on purchase status

## Setup

1. **Create a Cordova app:**
   ```bash
   cordova create DemoApp com.yourapp.demo "Demo App"
   cd DemoApp
   ```

2. **Add iOS platform:**
   ```bash
   cordova platform add ios
   ```

3. **Install the plugin:**
   ```bash
   cordova plugin add cordova-plugin-ios-purchase
   ```

4. **Copy example files:**
   ```bash
   cp examples/index.html www/
   cp examples/app.js www/js/
   cp examples/styles.css www/css/
   ```

5. **Update product IDs in app.js:**
   Replace the product IDs with your actual product IDs from App Store Connect:
   ```javascript
   const PRODUCT_IDS = {
       COINS_100: 'com.yourapp.coins100',
       COINS_500: 'com.yourapp.coins500',
       PREMIUM: 'com.yourapp.premium',
       MONTHLY: 'com.yourapp.monthly',
       YEARLY: 'com.yourapp.yearly'
   };
   ```

6. **Build and run:**
   ```bash
   cordova build ios
   cordova run ios
   ```

## Testing

### Sandbox Testing

1. Create sandbox test accounts in App Store Connect
2. Sign out of your Apple ID on the device
3. Run the app and make purchases
4. Sign in with sandbox account when prompted

### StoreKit Configuration (Xcode 12+)

For local testing without connecting to App Store Connect:

1. Open the project in Xcode: `platforms/ios/YourApp.xcworkspace`
2. Create a StoreKit Configuration file:
   - File > New > File
   - Select "StoreKit Configuration File"
   - Add your products with test data
3. Select the configuration in the scheme editor
4. Run from Xcode

## App Store Connect Setup

1. **Create Products:**
   - Go to App Store Connect > Your App > Features > In-App Purchases
   - Create products matching your product IDs
   - Set pricing and localization
   - Submit for review

2. **Consumables:**
   - Create "100 Coins" with ID: com.yourapp.coins100
   - Create "500 Coins" with ID: com.yourapp.coins500

3. **Non-Consumables:**
   - Create "Premium" with ID: com.yourapp.premium

4. **Auto-Renewable Subscriptions:**
   - Create subscription group
   - Create "Monthly" with ID: com.yourapp.monthly
   - Create "Yearly" with ID: com.yourapp.yearly
   - Set up pricing, billing period, and offers

5. **Get Shared Secret:**
   - App Store Connect > App Information
   - Copy shared secret for subscription validation

## Code Structure

### index.html
- UI layout with product cards
- Action buttons
- Transaction log

### app.js
- Plugin initialization
- Product loading
- Purchase handling
- Subscription management
- Error handling
- UI updates

### styles.css
- Modern, responsive design
- Product cards
- Status indicators
- Transaction log styling

## Key Functions

### loadProducts()
Loads all products and updates the UI with pricing information.

### buyProduct(productID)
Initiates a purchase for the specified product.

### handleTransaction(transaction)
Processes completed transactions and unlocks features.

### restorePurchases()
Restores all previous purchases.

### checkSubscriptions()
Checks and displays current subscription status.

### onTransactionUpdate(transaction)
Handles background transaction updates.

## Customization

### Adding New Products

1. Add product ID to `PRODUCT_IDS` object
2. Add UI card in index.html
3. Add case in `handleTransaction()` switch
4. Create product in App Store Connect

### Server-Side Validation

Replace the `handleTransaction()` function with server validation:

```javascript
async function handleTransaction(transaction) {
    try {
        const receipt = await iOSPurchase.getReceipt();

        const response = await fetch('https://yourserver.com/validate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                receipt,
                transaction: transaction,
                userId: getCurrentUserId()
            })
        });

        if (response.ok) {
            const result = await response.json();
            if (result.valid) {
                // Unlock features
                unlockFeatures(transaction.productID);
            }
        }
    } catch (error) {
        console.error('Validation failed:', error);
    }
}
```

## Troubleshooting

### "Product not found"
- Ensure product IDs match App Store Connect exactly
- Products must be "Ready to Submit" or "Approved"
- Wait 2-4 hours after creating products

### "Cannot connect to App Store"
- Check internet connection
- Try signing out and back in to App Store
- Use sandbox account for testing

### Purchases not restoring
- Ensure sandbox account has previous purchases
- Check that product IDs are correct
- Verify transaction observer is registered

## Production Checklist

- [ ] Replace product IDs with real ones
- [ ] Implement server-side receipt validation
- [ ] Add proper error handling and user messages
- [ ] Test all purchase flows thoroughly
- [ ] Test restore purchases
- [ ] Test subscription renewals
- [ ] Add loading indicators
- [ ] Handle pending purchases (Ask to Buy)
- [ ] Add analytics tracking
- [ ] Test on multiple devices and iOS versions

## Resources

- [Apple StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Plugin Documentation](../README.md)
