
# 3 Patti Social V1.5 — KYC + Cash-Readiness Gate

Version: **1.5.0+16**

This build adds the requested identity flow without selfie/video:
- full legal name
- email
- mobile number
- date of birth / 21+ declaration
- home address
- SSN or TIN (optional at initial submission)
- driver's license or passport

Security behavior:
- raw SSN/TIN is never persisted by this backend
- raw license/passport number is never persisted by this backend
- only last 4 + SHA-256 keyed hash are stored
- cash eligibility remains false until an approved KYC provider marks the user verified and confirms age/location

## Live-money safety gates
Real deposits/payouts do not activate just because UI is present. The backend requires ALL of these server-side gates:
- persistent Supabase/Postgres
- required auth secret
- REAL_MONEY_APPROVED=true
- IDENTITY_PROVIDER_READY=true
- KYC_PROVIDER_READY=true
- GEOLOCATION_PROVIDER_READY=true
- PAYMENT_PROVIDER_APPROVED=true
- REGULATORY_APPROVAL_ID set
- PAYMENT_APPROVAL_ID set
- CASH_MODE_ENABLED=true
- user KYC status = verified
- age verified
- current geo state in APPROVED_CASH_STATES
- user cash_eligible=true

`/deposit-live` and `/withdraw-live` are intentionally fail-closed until a real approved payment adapter + signed provider webhooks are connected. This prevents accidental fake or unapproved cash movement.

## New endpoints
- GET `/kyc/status?playerId=...`
- POST `/kyc/profile`
- POST `/kyc/provider-webhook`
- POST `/deposit-live` (fail-closed until provider adapter exists)
- POST `/withdraw-live` (fail-closed until provider adapter exists)

## Deploy
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v15_kyc_cash_ready.zip
rm three_patti_v15_kyc_cash_ready.zip
flutter pub get
git add .
git commit -m "V1.5 KYC and cash readiness"
git push
```

Run the updated `backend/schema.sql` in Supabase SQL Editor once; the new V1.5 statements are migration-safe (`add column if not exists`).
