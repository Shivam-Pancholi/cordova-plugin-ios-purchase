# Quick Start Guide

Get up and running with iOS In-App Purchases in 5 minutes.

## 1. Installation

```bash
cordova plugin add cordova-plugin-ios-purchase
```

## 2. App Store Connect Setup

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to "In-App Purchases" section
4. Create your products:
   - Click "+" to add a product
   - Choose product type (consumable, non-consumable, or subscription)
   - Fill in product ID (e.g., `com.yourapp.premium`)
   - Set price and metadata
   - Submit for review

## 3. Xcode Setup

1. Open your iOS project in Xcode
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "In-App Purchase"

## 4. Basic Implementation

Add this to your app:

```javascript
document.addEventListener('deviceready', initIAP);

async function initIAP() {
    // Your product IDs from App Store Connect
    const productIDs = ['com.yourapp.premium'];
    
    try {
        // Load products
        const products = await iOSPurchase.getProducts(productIDs);
        console.log('Products:', products);
        
        // Display products in your UI
        displayProducts(products);
        
    } catch (error) {
        console.error('IAP initialization failed:', error);
    }
}

function displayProducts(products) {
    products.forEach(product => {
        console.log(`${product.displayName}: ${product.priceFormatted}`);
        
        // Create buy button
        const button = document.createElement('button');
        button.textContent = `Buy ${product.displayName}`;
        button.onclick = () => buyProduct(product.id);
        document.body.appendChild(button);
    });
}

async function buyProduct(productId) {
    try {
        const transaction = await iOSPurchase.purchase(productId);
        console.log('Purchase successful!', transaction);
        
        // Unlock the feature
        unlockFeature(productId);
        
    } catch (error) {
        if (error.code === iOSPurchase.ErrorCode.USER_CANCELLED) {
            console.log('User cancelled');
        } else {
            console.error('Purchase failed:', error);
        }
    }
}

function unlockFeature(productId) {
    // Your code to unlock premium features
    console.log('Feature unlocked:', productId);
}
```

## 5. Testing

### Sandbox Testing

1. Create a Sandbox tester in App Store Connect:
   - Users and Access > Sandbox > Testers
   - Click "+" to add a tester
   - Use a unique email (doesn't need to be real)

2. On your test device:
   - Sign out of your Apple ID
   - Run your app
   - When prompted, sign in with sandbox account

3. Test purchases:
   - Purchases are free in sandbox
   - You can purchase the same item multiple times
   - Subscriptions renew every few minutes (not actual duration)

### StoreKit Testing (Faster)

1. In Xcode: File > New > File > StoreKit Configuration File
2. Add your products to the config
3. Edit Scheme > Run > Options > Select your StoreKit Config
4. Run your app - no internet needed!

## 6. Handle Restores

Always provide a restore button:

```javascript
async function restorePurchases() {
    try {
        const transactions = await iOSPurchase.restorePurchases();
        
        transactions.forEach(transaction => {
            unlockFeature(transaction.productID);
        });
        
        alert('Purchases restored!');
        
    } catch (error) {
        console.error('Restore failed:', error);
    }
}

// Add restore button to your UI
const restoreBtn = document.createElement('button');
restoreBtn.textContent = 'Restore Purchases';
restoreBtn.onclick = restorePurchases;
document.body.appendChild(restoreBtn);
```

## 7. Production Checklist

Before going live:

- [ ] Products approved in App Store Connect
- [ ] In-App Purchase capability enabled
- [ ] Test all purchases in sandbox
- [ ] Test restore purchases
- [ ] Implement server-side validation (see [Best Practices](BEST_PRACTICES.md))
- [ ] Add "Restore Purchases" button
- [ ] Handle all error cases
- [ ] Test on multiple devices
- [ ] Test with poor network
- [ ] Remove test code

## Next Steps

- Read the [full README](README.md) for complete API documentation
- Check [Best Practices](BEST_PRACTICES.md) for production guidelines
- See [examples/](examples/) for more code samples
- Implement server-side receipt validation

## Common Issues

### Products not loading?

- Wait 2-4 hours after creating products
- Ensure product IDs match exactly
- Check products are "Ready to Submit" status
- Verify In-App Purchase capability is enabled

### "Cannot connect to iTunes Store"?

- Check internet connection
- Sign out and sign in with sandbox account
- Wait a few minutes and try again
- Use StoreKit testing for offline development

### Purchase succeeds but no content?

- Check you're handling transaction updates
- Verify transaction is finished properly
- Look for errors in console

## Support

Need help? Check:
- [Full Documentation](README.md)
- [Best Practices Guide](BEST_PRACTICES.md)
- [GitHub Issues](https://github.com/Shivam-Pancholi/cordova-plugin-ios-purchase/issues)
- [Apple's IAP Documentation](https://developer.apple.com/in-app-purchase/)

Happy coding! 🎉
