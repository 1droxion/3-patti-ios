# 3 Patti Social V1.7.1 — iOS Compile Fix

Fixes the V1.7 App Store launch-candidate compile errors: restores the shared PageFrame widget and removes the invalid const constructor from ThreePattiApp. StoreKit deprecation messages in Xcode are warnings, not build blockers. Version 1.7.1+19.

# 3 Patti Social V1.7 Launch Candidate — Build 19

Public social-only App Store candidate.

Changes:
- Removes dormant KYC, PayPal, bank, deposit and withdrawal UI from the public Flutter binary.
- Social chips only; no cash value or redemption.
- Real server-side account deletion from Settings.
- Working in-app support ticket form.
- Public Privacy, Terms and Support pages hosted by the backend.
- App Store IAP delivery now fails closed: StoreKit transactions are completed only after server delivery succeeds.
- Live IAP requires persistent storage and Apple server verification.
- Apple transaction verification automatically tries production then sandbox for App Review/TestFlight compatibility.
- VIP uses Apple's verified subscription expiration when live.
- Backend fails closed in public mode if Supabase/auth are not configured.
- Version 1.7.1+18.

## Install
Upload this ZIP into the root of your existing repo and run:

```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v17_app_store_launch.zip
rm three_patti_v17_app_store_launch.zip
flutter pub get
git add .
git commit -m "V1.7 App Store social launch candidate"
git push
```

Then configure Vercel using backend/.env.example and run backend/schema.sql in Supabase.
See app_store_launch/ for App Store metadata, IAP IDs, privacy guidance, review notes, age-rating guidance and the final launch checklist.
