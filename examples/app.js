/**
 * Example App for iOS Purchase Plugin
 */

// Product IDs - Replace with your actual product IDs
const PRODUCT_IDS = {
    COINS_100: 'com.yourapp.coins100',
    COINS_500: 'com.yourapp.coins500',
    PREMIUM: 'com.yourapp.premium',
    MONTHLY: 'com.yourapp.monthly',
    YEARLY: 'com.yourapp.yearly'
};

// Initialize app
document.addEventListener('deviceready', onDeviceReady, false);

function onDeviceReady() {
    log('Device ready!', 'success');
    updateStatus('Device ready. Initializing plugin...');

    // Register transaction observer
    if (window.iOSPurchase) {
        iOSPurchase.registerTransactionObserver(onTransactionUpdate);
        log('Transaction observer registered', 'info');

        // Load products automatically
        loadProducts();
    } else {
        log('ERROR: iOSPurchase plugin not found', 'error');
        updateStatus('Plugin not available. Are you running on iOS?');
    }
}

// Transaction observer callback
function onTransactionUpdate(transaction) {
    log('Transaction update received:', 'info');
    log(JSON.stringify(transaction, null, 2), 'info');

    // Handle the transaction
    handleTransaction(transaction);
}

// Load all products
async function loadProducts() {
    try {
        updateStatus('Loading products...');
        log('Fetching products from App Store...', 'info');

        const productIDs = Object.values(PRODUCT_IDS);
        const products = await iOSPurchase.getProducts(productIDs);

        log(`Loaded ${products.length} products`, 'success');

        // Update UI with product info
        products.forEach(product => {
            updateProductUI(product);
        });

        // Check purchased status
        await updatePurchasedStatus();

        updateStatus('Products loaded successfully!');
    } catch (error) {
        log(`Error loading products: ${error.message}`, 'error');
        updateStatus('Failed to load products. Check console for details.');
    }
}

// Update product UI with info
function updateProductUI(product) {
    log(`Product: ${product.displayName} - ${product.priceFormatted}`, 'info');

    // Update price display
    const priceElement = document.getElementById(`price-${product.id.split('.').pop()}`);
    if (priceElement) {
        priceElement.textContent = product.priceFormatted;
    }

    // Log subscription info if available
    if (product.subscriptionInfo) {
        log(`  Subscription: ${product.subscriptionInfo.subscriptionPeriod}`, 'info');
        if (product.subscriptionInfo.introductoryOffer) {
            log(`  Intro offer: ${product.subscriptionInfo.introductoryOffer.priceFormatted}`, 'info');
        }
    }
}

// Update purchased status
async function updatePurchasedStatus() {
    try {
        const purchased = await iOSPurchase.getPurchasedProducts();
        log(`Purchased products: ${purchased.join(', ')}`, 'info');

        // Update premium status
        if (purchased.includes(PRODUCT_IDS.PREMIUM)) {
            const statusElement = document.getElementById('premium-status');
            if (statusElement) {
                statusElement.textContent = 'Purchased ';
                statusElement.className = 'badge badge-success';
            }

            const btnElement = document.getElementById('btn-premium');
            if (btnElement) {
                btnElement.textContent = 'Purchased';
                btnElement.disabled = true;
            }
        }

        // Check subscription status
        await checkSubscriptions();
    } catch (error) {
        log(`Error checking purchased status: ${error.message}`, 'error');
    }
}

// Buy a product
async function buyProduct(productID) {
    try {
        updateStatus(`Purchasing ${productID}...`);
        log(`Initiating purchase: ${productID}`, 'info');

        const transaction = await iOSPurchase.purchase(productID);

        log('Purchase successful!', 'success');
        log(JSON.stringify(transaction, null, 2), 'success');

        updateStatus('Purchase successful!');

        // Handle the purchase
        handleTransaction(transaction);

        // Update UI
        await updatePurchasedStatus();
    } catch (error) {
        handlePurchaseError(error);
    }
}

// Handle transaction
function handleTransaction(transaction) {
    log(`Handling transaction for: ${transaction.productID}`, 'info');

    // In a real app, validate the transaction with your server here
    // Then unlock the features

    switch (transaction.productID) {
        case PRODUCT_IDS.COINS_100:
            log('Awarding 100 coins', 'success');
            // Award coins to user
            break;

        case PRODUCT_IDS.COINS_500:
            log('Awarding 500 coins', 'success');
            // Award coins to user
            break;

        case PRODUCT_IDS.PREMIUM:
            log('Unlocking premium features', 'success');
            // Unlock premium
            break;

        case PRODUCT_IDS.MONTHLY:
        case PRODUCT_IDS.YEARLY:
            log('Activating subscription', 'success');
            // Activate subscription features
            break;
    }
}

// Handle purchase errors
function handlePurchaseError(error) {
    let message = error.message;

    switch (error.code) {
        case iOSPurchase.ErrorCode.USER_CANCELLED:
            message = 'Purchase cancelled by user';
            log(message, 'info');
            break;

        case iOSPurchase.ErrorCode.NETWORK_ERROR:
            message = 'Network error. Please check your connection.';
            log(message, 'error');
            break;

        case iOSPurchase.ErrorCode.PURCHASE_NOT_ALLOWED:
            message = 'Purchases are disabled on this device';
            log(message, 'error');
            break;

        case iOSPurchase.ErrorCode.INVALID_PRODUCT_ID:
            message = 'Product not found in App Store';
            log(message, 'error');
            break;

        default:
            log(`Purchase failed: ${message}`, 'error');
    }

    updateStatus(message);
}

// Restore purchases
async function restorePurchases() {
    try {
        updateStatus('Restoring purchases...');
        log('Restoring purchases...', 'info');

        const transactions = await iOSPurchase.restorePurchases();

        if (transactions.length > 0) {
            log(`Restored ${transactions.length} purchases`, 'success');
            transactions.forEach(transaction => {
                log(`  - ${transaction.productID}`, 'info');
                handleTransaction(transaction);
            });
            updateStatus(`Restored ${transactions.length} purchases`);
        } else {
            log('No purchases to restore', 'info');
            updateStatus('No purchases to restore');
        }

        await updatePurchasedStatus();
    } catch (error) {
        log(`Restore failed: ${error.message}`, 'error');
        updateStatus('Restore failed');
    }
}

// Check subscription status
async function checkSubscriptions() {
    try {
        log('Checking subscription status...', 'info');

        // Check monthly subscription
        const monthlyStatus = await iOSPurchase.getSubscriptionStatus(PRODUCT_IDS.MONTHLY);
        updateSubscriptionUI('monthly', monthlyStatus);

        // Check yearly subscription
        const yearlyStatus = await iOSPurchase.getSubscriptionStatus(PRODUCT_IDS.YEARLY);
        updateSubscriptionUI('yearly', yearlyStatus);

    } catch (error) {
        log(`Error checking subscriptions: ${error.message}`, 'error');
    }
}

// Update subscription UI
function updateSubscriptionUI(type, status) {
    const statusElement = document.getElementById(`${type}-status`);
    if (!statusElement) return;

    if (!status) {
        statusElement.innerHTML = '<p>No active subscription</p>';
        return;
    }

    const isActive = iOSPurchase.isSubscriptionActive(status);
    const expirationDate = iOSPurchase.getSubscriptionExpirationDate(status);

    let html = '<div class="subscription-info">';
    html += `<p><strong>State:</strong> ${status.state}</p>`;

    if (expirationDate) {
        html += `<p><strong>Expires:</strong> ${expirationDate.toLocaleDateString()}</p>`;
    }

    if (status.renewalInfo) {
        html += `<p><strong>Auto-renew:</strong> ${status.renewalInfo.willAutoRenew ? 'Yes' : 'No'}</p>`;
    }

    html += `<p><strong>Status:</strong> ${isActive ? ' Active' : ' Inactive'}</p>`;
    html += '</div>';

    statusElement.innerHTML = html;

    log(`${type} subscription: ${status.state}`, isActive ? 'success' : 'info');
}

// Get purchased products
async function getPurchased() {
    try {
        const purchased = await iOSPurchase.getPurchasedProducts();

        if (purchased.length > 0) {
            log('Purchased products:', 'success');
            purchased.forEach(productID => {
                log(`  - ${productID}`, 'success');
            });
        } else {
            log('No purchased products', 'info');
        }

        updateStatus(`Purchased: ${purchased.length} items`);
    } catch (error) {
        log(`Error: ${error.message}`, 'error');
    }
}

// Get receipt
async function getReceipt() {
    try {
        log('Fetching receipt...', 'info');

        const receipt = await iOSPurchase.getReceipt();

        log('Receipt retrieved (first 100 chars):', 'success');
        log(receipt.substring(0, 100) + '...', 'info');

        updateStatus('Receipt retrieved. Check log.');

        // In a real app, send this to your server for validation
        // await validateReceiptOnServer(receipt);
    } catch (error) {
        log(`Error: ${error.message}`, 'error');
        updateStatus('Failed to get receipt');
    }
}

// UI Helper Functions

function updateStatus(message) {
    const statusElement = document.getElementById('status');
    if (statusElement) {
        statusElement.innerHTML = `<p>${message}</p>`;
    }
}

function log(message, type = 'info') {
    console.log(message);

    const logElement = document.getElementById('log');
    if (!logElement) return;

    const time = new Date().toLocaleTimeString();
    const entry = document.createElement('div');
    entry.className = `log-entry log-${type}`;
    entry.innerHTML = `<span class="log-time">[${time}]</span> ${escapeHtml(message)}`;

    logElement.appendChild(entry);
    logElement.scrollTop = logElement.scrollHeight;
}

function clearLog() {
    const logElement = document.getElementById('log');
    if (logElement) {
        logElement.innerHTML = '';
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
