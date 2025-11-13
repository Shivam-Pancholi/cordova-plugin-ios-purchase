# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-13

### Added
- Initial release of cordova-plugin-ios-purchase
- StoreKit 2 support for iOS 15+
- Complete product management
  - Fetch products from App Store
  - Support for all product types (consumable, non-consumable, subscriptions)
  - Product information including pricing and subscription details
- Purchase functionality
  - Purchase products
  - Purchase with promotional offers
  - Automatic transaction verification
  - Transaction finishing
- Transaction management
  - Restore purchases
  - Get current entitlements
  - Check if product is purchased
  - Real-time transaction updates
- Subscription features
  - Get subscription status
  - Get subscription statuses for groups
  - Renewal information
  - Grace period handling
  - Billing retry detection
  - Introductory and promotional offers
- Receipt management
  - Get App Store receipt
  - Refresh receipt
  - Base64 encoded receipt data
- Refund support
  - In-app refund requests
  - Refund status tracking
- Event system
  - Transaction update events
  - Automatic renewal notifications
  - Refund notifications
- TypeScript support
  - Full type definitions
  - Complete interface documentation
- Comprehensive error handling
  - Detailed error codes
  - User-friendly error messages
- Security features
  - Automatic transaction verification
  - Receipt validation support
  - Server-side validation ready
- Documentation
  - Complete API documentation
  - Usage examples
  - Best practices guide
  - Subscription management examples
  - TypeScript examples

### Technical Details
- Minimum iOS version: 15.0
- Minimum Cordova version: 9.0.0
- Minimum Cordova iOS version: 6.0.0
- Built with Swift 5+
- Uses modern async/await patterns
- Actor-based thread-safe implementation

### Notes
- This is the first production-ready release
- Tested with iOS 15.0+
- Full StoreKit 2 implementation
- Backward compatible design for future updates

## [Unreleased]

### Planned
- iOS 14 fallback support using StoreKit 1
- Offer code redemption
- Ask to buy support detection
- Enhanced family sharing features
- Extended receipt validation utilities
- Subscription offer eligibility checking
- Price change consent handling
