
# 3 Patti Social V1.3 — Payment Rails + Tip Fix

Version: `1.3.0+14`

## Added
- Wallet deposit choices: Apple Pay, Cash App Pay, debit/credit card.
- Withdraw choices: PayPal and Bank / ACH.
- Server `/payments-config` feature gate.
- Deposit and withdrawal sandbox request endpoints.
- Dealer tip rewritten with a reliable dialog, instant local chip animation/update, and rollback if the server rejects it.

## Important
Real-money cash mode is intentionally OFF by default. Set `CASH_MODE_ENABLED=true` only after the required gaming licence/partner approvals and payment-provider approvals are in place. This package does not contain merchant secrets and does not send real money.

## Install
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v13_payments_tip_fix.zip
rm three_patti_v13_payments_tip_fix.zip
flutter pub get
git add .
git commit -m "V1.3 payment rails and dealer tip fix"
git push
```

After Vercel deploys, `/health` should show `1.3.0`. Codemagic should build Version `1.3.0`, Build `14`.
