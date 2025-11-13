/**
 * Subscription Management Example
 * This example demonstrates advanced subscription features
 */

const SUBSCRIPTION_GROUP = 'premium_group';
const PRODUCT_IDS = {
    monthly: 'com.yourapp.premium_monthly',
    yearly: 'com.yourapp.premium_yearly'
};

/**
 * Load and display subscription options
 */
async function loadSubscriptionOptions() {
    try {
        // Fetch all subscription products
        const products = await iOSPurchase.getProducts(Object.values(PRODUCT_IDS));

        // Display subscription tiers
        products.forEach(product => {
            displaySubscriptionOption(product);
        });

        // Check current subscription status
        await checkCurrentSubscription();

    } catch (error) {
        console.error('Failed to load subscriptions:', error);
    }
}

/**
 * Display subscription option in UI
 */
function displaySubscriptionOption(product) {
    const container = document.getElementById('subscription-options');

    const subEl = document.createElement('div');
    subEl.className = 'subscription-option';

    // Calculate monthly price for comparison
    const isYearly = product.id === PRODUCT_IDS.yearly;
    const monthlyPrice = isYearly ? (product.price / 12).toFixed(2) : product.price;

    // Show introductory offer if available
    let introOffer = '';
    if (product.subscriptionInfo && product.subscriptionInfo.introductoryOffer) {
        const offer = product.subscriptionInfo.introductoryOffer;
        introOffer = '<div class="intro-offer"><strong>Special Offer:</strong> ' + offer.priceFormatted + ' for ' + offer.periodCount + ' ' + offer.period + '</div>';
    }

    subEl.innerHTML = '<h3>' + product.displayName + '</h3>' +
        '<p class="price">' + product.priceFormatted + '</p>' +
        (isYearly ? '<p class="monthly-price">Just ' + product.currencyCode + ' ' + monthlyPrice + '/month</p>' : '') +
        '<p>' + product.description + '</p>' +
        introOffer +
        '<button onclick="subscribe(\'' + product.id + '\')">Subscribe</button>';

    container.appendChild(subEl);
}

/**
 * Subscribe to a plan
 */
async function subscribe(productId) {
    try {
        showLoading('Processing subscription...');

        // Check if user has an active subscription
        const currentSub = await getCurrentActiveSubscription();

        if (currentSub) {
            // User is upgrading/downgrading
            const confirmUpgrade = confirm(
                'You already have an active subscription. Do you want to switch to this plan?'
            );

            if (!confirmUpgrade) {
                hideLoading();
                return;
            }
        }

        // Purchase the subscription
        const transaction = await iOSPurchase.purchase(productId);

        console.log('Subscription successful:', transaction);

        // Verify and activate
        await verifyAndActivateSubscription(transaction);

        hideLoading();
        showSuccess('Subscription activated!');

        // Update UI
        await checkCurrentSubscription();

    } catch (error) {
        hideLoading();
        handleSubscriptionError(error);
    }
}

/**
 * Subscribe with promotional offer
 */
async function subscribeWithOffer(productId, offerId) {
    try {
        showLoading('Processing promotional offer...');

        const transaction = await iOSPurchase.purchase(productId, offerId);

        console.log('Subscription with offer successful:', transaction);

        await verifyAndActivateSubscription(transaction);

        hideLoading();
        showSuccess('Promotional subscription activated!');

    } catch (error) {
        hideLoading();
        handleSubscriptionError(error);
    }
}

/**
 * Check current subscription status
 */
async function checkCurrentSubscription() {
    try {
        // Get all statuses for the subscription group
        const statuses = await iOSPurchase.getSubscriptionStatuses(SUBSCRIPTION_GROUP);

        if (statuses.length === 0) {
            // No active subscription
            showNoSubscriptionUI();
            return null;
        }

        // Find the active subscription
        const activeStatus = statuses.find(s => s.state === 'subscribed' || s.state === 'inGracePeriod');

        if (activeStatus) {
            showActiveSubscriptionUI(activeStatus);
            return activeStatus;
        } else {
            // Subscription expired or revoked
            showExpiredSubscriptionUI();
            return null;
        }

    } catch (error) {
        console.error('Failed to check subscription:', error);
        return null;
    }
}

/**
 * Get current active subscription
 */
async function getCurrentActiveSubscription() {
    const statuses = await iOSPurchase.getSubscriptionStatuses(SUBSCRIPTION_GROUP);
    return statuses.find(s => s.state === 'subscribed' || s.state === 'inGracePeriod');
}

/**
 * Show active subscription UI
 */
function showActiveSubscriptionUI(status) {
    const container = document.getElementById('subscription-status');

    const renewalInfo = status.renewalInfo;
    const transaction = status.transaction;

    // Format expiration date
    const expirationDate = transaction.expirationDate
        ? new Date(transaction.expirationDate).toLocaleDateString()
        : 'N/A';

    // Check renewal status
    let renewalMessage = '';
    if (renewalInfo) {
        if (renewalInfo.willAutoRenew) {
            renewalMessage = '<p class="renewal-on">Auto-renewal is ON. Next billing: ' + expirationDate + '</p>';
        } else {
            renewalMessage = '<p class="renewal-off">Auto-renewal is OFF. Access until: ' + expirationDate + '</p>';

            if (renewalInfo.expirationReason) {
                renewalMessage += '<p class="expiration-reason">Reason: ' + formatExpirationReason(renewalInfo.expirationReason) + '</p>';
            }
        }
    }

    // Handle grace period
    let gracePeriodMessage = '';
    if (status.state === 'inGracePeriod') {
        gracePeriodMessage = '<div class="warning-box"><strong>Payment Issue</strong><p>There\'s a problem with your payment method. Please update it to continue your subscription.</p><button onclick="openSubscriptionSettings()">Update Payment</button></div>';
    }

    container.innerHTML = '<div class="active-subscription"><h3>Active Subscription</h3><p><strong>Plan:</strong> ' + status.productID + '</p>' + renewalMessage + gracePeriodMessage + '<button onclick="manageSubscription()">Manage Subscription</button><button onclick="requestRefund(\'' + transaction.id + '\')">Request Refund</button></div>';
}

/**
 * Show no subscription UI
 */
function showNoSubscriptionUI() {
    const container = document.getElementById('subscription-status');
    container.innerHTML = '<div class="no-subscription"><p>You don\'t have an active subscription</p><button onclick="loadSubscriptionOptions()">View Plans</button></div>';
}

/**
 * Show expired subscription UI
 */
function showExpiredSubscriptionUI() {
    const container = document.getElementById('subscription-status');
    container.innerHTML = '<div class="expired-subscription"><p>Your subscription has expired</p><button onclick="loadSubscriptionOptions()">Resubscribe</button></div>';
}

/**
 * Manage subscription (opens iOS subscription settings)
 */
function manageSubscription() {
    // Open iOS subscription management
    // This will navigate to Settings > Apple ID > Subscriptions
    if (window.open) {
        window.open('https://apps.apple.com/account/subscriptions', '_system');
    }
}

/**
 * Request refund for a transaction
 */
async function requestRefund(transactionId) {
    try {
        const confirmed = confirm('Do you want to request a refund for this subscription?');

        if (!confirmed) return;

        const status = await iOSPurchase.beginRefundRequest(transactionId);

        if (status === 'success') {
            alert('Refund request submitted. You will be notified of the outcome.');
        } else if (status === 'userCancelled') {
            console.log('User cancelled refund request');
        }

    } catch (error) {
        console.error('Refund request failed:', error);
        alert('Failed to request refund. Please try again or contact support.');
    }
}

/**
 * Open subscription settings in iOS
 */
function openSubscriptionSettings() {
    manageSubscription();
}

/**
 * Verify and activate subscription
 */
async function verifyAndActivateSubscription(transaction) {
    // Verify with your server
    const isValid = await verifyTransactionWithServer(transaction);

    if (isValid) {
        // Activate subscription features
        activateSubscriptionFeatures(transaction.productID);

        // Store subscription info locally
        localStorage.setItem('subscriptionProductId', transaction.productID);
        localStorage.setItem('subscriptionTransactionId', transaction.id);
    } else {
        throw new Error('Subscription verification failed');
    }
}

/**
 * Handle subscription errors
 */
function handleSubscriptionError(error) {
    console.error('Subscription error:', error);

    switch (error.code) {
        case iOSPurchase.ErrorCode.USER_CANCELLED:
            // User cancelled - no action needed
            break;

        case iOSPurchase.ErrorCode.PURCHASE_NOT_ALLOWED:
            alert('Subscriptions are not allowed on this device. Please check your settings.');
            break;

        case iOSPurchase.ErrorCode.NETWORK_ERROR:
            alert('Network error. Please check your connection and try again.');
            break;

        default:
            alert('Subscription failed. Please try again or contact support.');
    }
}

/**
 * Format expiration reason for display
 */
function formatExpirationReason(reason) {
    switch (reason) {
        case 'autoRenewDisabled':
            return 'Auto-renewal was disabled';
        case 'billingError':
            return 'Billing error occurred';
        case 'didNotConsentToPriceIncrease':
            return 'Did not consent to price increase';
        case 'productUnavailable':
            return 'Product is no longer available';
        default:
            return reason;
    }
}

// App-specific functions
async function verifyTransactionWithServer(transaction) {
    // Implement server verification
    return true;
}

function activateSubscriptionFeatures(productId) {
    console.log('Activating subscription features for:', productId);
    // Implement feature activation
}

function showLoading(message) { console.log('Loading:', message); }
function hideLoading() { console.log('Loading complete'); }
function showSuccess(message) { alert(message); }
