/**
 * Basic Usage Example
 * This example demonstrates the core functionality of the iOS Purchase Plugin
 */

// Wait for device to be ready
document.addEventListener('deviceready', onDeviceReady, false);

async function onDeviceReady() {
    console.log('Device ready - initializing IAP');
    
    // Set up transaction listener
    setupTransactionListener();
    
    // Load products
    await loadProducts();
}

// Product IDs (replace with your actual product IDs)
const PRODUCT_IDS = {
    consumable: 'com.yourapp.coins_100',
    nonConsumable: 'com.yourapp.premium',
    subscription: 'com.yourapp.premium_monthly'
};

/**
 * Set up listener for transaction updates
 */
function setupTransactionListener() {
    const removeListener = iOSPurchase.onTransactionUpdate(async (transaction) => {
        console.log('Transaction update received:', transaction);
        
        // Handle the transaction
        await handleTransaction(transaction);
    });
    
    // Store removeListener if you need to clean up later
    window.iapListenerRemover = removeListener;
}

/**
 * Load products from the App Store
 */
async function loadProducts() {
    try {
        const products = await iOSPurchase.getProducts(Object.values(PRODUCT_IDS));
        
        console.log('Products loaded:', products);
        
        // Display products in UI
        products.forEach(product => {
            displayProduct(product);
        });
        
    } catch (error) {
        console.error('Failed to load products:', error);
        showError('Failed to load products. Please try again.');
    }
}

/**
 * Display product in UI
 */
function displayProduct(product) {
    const container = document.getElementById('products');
    
    const productEl = document.createElement('div');
    productEl.className = 'product';
    productEl.innerHTML = `
        <h3>${product.displayName}</h3>
        <p>${product.description}</p>
        <p class="price">${product.priceFormatted}</p>
        <button onclick="purchaseProduct('${product.id}')">Buy Now</button>
    `;
    
    container.appendChild(productEl);
}

/**
 * Purchase a product
 */
async function purchaseProduct(productId) {
    try {
        console.log('Purchasing:', productId);
        
        // Show loading indicator
        showLoading('Processing purchase...');
        
        // Make the purchase
        const transaction = await iOSPurchase.purchase(productId);
        
        console.log('Purchase successful:', transaction);
        
        // Handle the successful purchase
        await handleTransaction(transaction);
        
        hideLoading();
        showSuccess('Purchase successful!');
        
    } catch (error) {
        hideLoading();
        
        console.error('Purchase failed:', error);
        
        // Handle specific error cases
        switch (error.code) {
            case iOSPurchase.ErrorCode.USER_CANCELLED:
                console.log('User cancelled purchase');
                // No message needed
                break;
                
            case iOSPurchase.ErrorCode.NETWORK_ERROR:
                showError('Network error. Please check your connection and try again.');
                break;
                
            case iOSPurchase.ErrorCode.PURCHASE_NOT_ALLOWED:
                showError('Purchases are not allowed on this device. Please check your settings.');
                break;
                
            case iOSPurchase.ErrorCode.PENDING:
                showInfo('Purchase is pending approval.');
                break;
                
            default:
                showError('Purchase failed. Please try again.');
        }
    }
}

/**
 * Handle a transaction (validate and unlock content)
 */
async function handleTransaction(transaction) {
    console.log('Handling transaction:', transaction);
    
    // Check if transaction was refunded
    if (transaction.revocationDate) {
        console.log('Transaction was refunded');
        revokeAccess(transaction.productID);
        return;
    }
    
    // Verify transaction with your server
    const isValid = await verifyTransactionWithServer(transaction);
    
    if (isValid) {
        // Unlock the content/feature
        unlockContent(transaction.productID);
    } else {
        console.error('Transaction verification failed');
        showError('Purchase verification failed. Please contact support.');
    }
}

/**
 * Verify transaction with your server
 */
async function verifyTransactionWithServer(transaction) {
    try {
        // Get receipt data
        const receipt = await iOSPurchase.getReceipt();
        
        // Send to your server for verification
        const response = await fetch('https://yourserver.com/api/verify-receipt', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + getUserToken() // Your auth token
            },
            body: JSON.stringify({
                receipt: receipt.receiptData,
                transactionId: transaction.id,
                productId: transaction.productID
            })
        });
        
        const result = await response.json();
        
        return result.valid === true;
        
    } catch (error) {
        console.error('Server verification failed:', error);
        return false;
    }
}

/**
 * Unlock content based on product ID
 */
function unlockContent(productId) {
    console.log('Unlocking content for:', productId);
    
    switch (productId) {
        case PRODUCT_IDS.consumable:
            // Add coins to user's account
            addCoins(100);
            break;
            
        case PRODUCT_IDS.nonConsumable:
            // Unlock premium features
            enablePremiumFeatures();
            break;
            
        case PRODUCT_IDS.subscription:
            // Enable subscription features
            enableSubscription();
            break;
    }
    
    // Update UI
    updateUI();
}

/**
 * Revoke access (for refunded transactions)
 */
function revokeAccess(productId) {
    console.log('Revoking access for:', productId);
    
    switch (productId) {
        case PRODUCT_IDS.nonConsumable:
            disablePremiumFeatures();
            break;
            
        case PRODUCT_IDS.subscription:
            disableSubscription();
            break;
    }
    
    updateUI();
}

/**
 * Restore purchases
 */
async function restorePurchases() {
    try {
        showLoading('Restoring purchases...');
        
        const transactions = await iOSPurchase.restorePurchases();
        
        console.log('Restored transactions:', transactions);
        
        if (transactions.length > 0) {
            // Process each restored transaction
            for (const transaction of transactions) {
                await handleTransaction(transaction);
            }
            
            showSuccess(`Restored ${transactions.length} purchase(s)`);
        } else {
            showInfo('No purchases to restore');
        }
        
        hideLoading();
        
    } catch (error) {
        hideLoading();
        console.error('Restore failed:', error);
        showError('Failed to restore purchases. Please try again.');
    }
}

/**
 * Check subscription status
 */
async function checkSubscriptionStatus() {
    try {
        const status = await iOSPurchase.getSubscriptionStatus(PRODUCT_IDS.subscription);
        
        if (!status) {
            console.log('No active subscription');
            return false;
        }
        
        console.log('Subscription status:', status);
        
        switch (status.state) {
            case 'subscribed':
                enableSubscription();
                return true;
                
            case 'inGracePeriod':
                enableSubscription();
                showWarning('Your subscription has a payment issue. Please update your payment method.');
                return true;
                
            case 'inBillingRetryPeriod':
                disableSubscription();
                showError('Your subscription has expired due to a payment issue. Please update your payment method.');
                return false;
                
            case 'expired':
                disableSubscription();
                return false;
                
            case 'revoked':
                disableSubscription();
                return false;
                
            default:
                return false;
        }
        
    } catch (error) {
        console.error('Failed to check subscription status:', error);
        return false;
    }
}

// UI Helper Functions (implement these based on your UI framework)
function showLoading(message) { console.log('Loading:', message); }
function hideLoading() { console.log('Loading complete'); }
function showSuccess(message) { alert(message); }
function showError(message) { alert('Error: ' + message); }
function showInfo(message) { alert(message); }
function showWarning(message) { alert('Warning: ' + message); }
function updateUI() { console.log('UI updated'); }

// App-specific functions (implement these based on your app logic)
function addCoins(amount) { console.log('Added coins:', amount); }
function enablePremiumFeatures() { console.log('Premium enabled'); }
function disablePremiumFeatures() { console.log('Premium disabled'); }
function enableSubscription() { console.log('Subscription enabled'); }
function disableSubscription() { console.log('Subscription disabled'); }
function getUserToken() { return 'your-auth-token'; }
