# 3 Patti Social V1.6 — Social Launch Monetization

Version: **1.6.0+17**

This is the social-only launch build. Real-money deposit/withdrawal UI is removed from normal navigation. The dormant future cash/KYC backend foundation remains in the codebase, but cash mode stays OFF.

## Social monetization in this build

Apple In-App Purchase is wired through Flutter's official `in_app_purchase` plugin.

Create these products in App Store Connect with the exact Product IDs:

### Consumable IAPs
- `com.droxion.threepatti.chips25k` — 25K Social Chips — suggested $0.99
- `com.droxion.threepatti.chips150k` — 150K Social Chips — suggested $4.99
- `com.droxion.threepatti.chips400k` — 400K Social Chips — suggested $9.99
- `com.droxion.threepatti.chips1m` — 1M Social Chips — suggested $19.99

### Auto-renewable subscription
- `com.droxion.threepatti.vip.monthly` — VIP Monthly — suggested $6.99/month

VIP currently gives a visible VIP badge/status. Add more cosmetic VIP benefits later, but do not make VIP change card odds.

## Important social-chip rule

Purchased chips are virtual entertainment credits only:
- no cash value
- no PayPal/bank withdrawal
- no USD conversion
- no transfer or resale
- no physical prize redemption

The 5% table fee is a virtual-chip economy sink, not a cash gambling rake in this release.

## App Store purchase security

`SOCIAL_IAP_MODE=sandbox` is for TestFlight/development.

For production, set `SOCIAL_IAP_MODE=live` only after Apple server transaction verification credentials are configured:
- `APPLE_BUNDLE_ID=com.droxion.threepatti`
- `APPLE_IAP_ISSUER_ID`
- `APPLE_IAP_KEY_ID`
- `APPLE_IAP_PRIVATE_KEY`
- `APPLE_IAP_ENV=production`

When live mode is enabled the backend verifies the transaction with Apple's App Store Server API before delivering chips/VIP. Transaction IDs are idempotent, so the same purchase cannot be credited twice.

## What changed from V1.5

- New Social Store
- 4 virtual chip packs
- VIP Monthly
- StoreKit purchase stream + restore purchases
- server-side social product catalog
- server wallet delivery after purchase claim
- duplicate transaction protection
- Apple App Store Server API verification path for live mode
- VIP status stored in backend and displayed at player seats
- Withdraw removed from menu
- Cash deposit methods removed from player-facing Wallet
- KYC button removed from normal Profile
- Wallet renamed Social Chips
- Rules rewritten for social-only launch
- Version 1.6.0 Build 17

## Install in Codespaces

```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v16_social_launch.zip
rm three_patti_v16_social_launch.zip
flutter pub get
git add .
git commit -m "V1.6 social launch monetization"
git push
```

## Vercel

Keep real-money switches OFF.

For TestFlight social IAP testing add:

```text
SOCIAL_IAP_MODE=sandbox
APPLE_IAP_ENV=sandbox
APPLE_BUNDLE_ID=com.droxion.threepatti
```

The Apple server credentials can be added when you are ready for production receipt verification.

## Before App Store public launch

1. Complete Apple's Paid Apps agreement / tax / banking setup in App Store Connect.
2. Create the 4 consumable IAP products above.
3. Create a subscription group and the VIP Monthly subscription.
4. Add product names/descriptions/prices and review information.
5. Test all purchases in TestFlight/Sandbox.
6. Configure Apple server transaction credentials on Vercel.
7. Set `SOCIAL_IAP_MODE=live` only after verification works.
8. Submit the app + IAPs/subscription for App Review.

## Rewarded ads

Not enabled in this ZIP yet. AdMob needs your own AdMob iOS App ID and Rewarded Ad Unit ID in the iOS project. Do not publish using Google's test ad IDs. Add this after the App Store social-chip purchase flow is stable.
