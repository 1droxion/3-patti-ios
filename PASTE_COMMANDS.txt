
# 3 Patti Social V1.1 — Faster Actions + Live Lobby + PayPal Sandbox

Drop this ZIP into the root of the existing `3-patti-ios` repo. It intentionally does not overwrite `ios/`.

## V1.1 changes
- Blind / Chaal now feel immediate with optimistic local chip + pot animation, then reconcile with the authoritative server response.
- Reuses one HTTP connection instead of creating a new TLS connection for every poll/action.
- Prevents stale polling responses from overwriting a just-tapped action.
- Turn timer uses the server-provided duration for better accuracy.
- Home hero / “Choose Your Table” box removed.
- Home is now a full live-table carousel with round rotating room wheels.
- Round rooms show real prototype waiting/active room state from `/lobby`; no fake player counts.
- Green 2–5 = 5K, Blue 6–8 = 20K, Gold 9–10 = 50K.
- PayPal withdrawal screen added in SANDBOX mode only. It creates a demo request but sends no money.
- Sandbox preview uses 100 chips = $1.00 only as a UI/testing preview. Social chips have no cash value in this build.
- Version 1.1.0+12.

## Install
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v11_live_lobby_fast_actions.zip
rm three_patti_v11_live_lobby_fast_actions.zip
flutter pub get
git add .
git commit -m "V1.1 fast table live lobby PayPal sandbox"
git push
```

After Vercel redeploys, `/health` should show version `1.1.0`. Build in Codemagic as Version 1.1.0 / Build 12.

## Important
The current Vercel room store is still in memory and is for prototype testing only. Before real-money launch, move rooms/wallets/transactions to persistent regulated infrastructure. Real PayPal gaming payouts are intentionally not connected in this build.
