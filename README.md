# 3 Patti Social v0.5 — Premium Full-Screen Home

This ZIP is a **drop-in update** for the existing `3-patti-ios` GitHub repository.
It does **not** include or overwrite the repo's existing `ios/` folder, so the Apple bundle ID, code signing, and TestFlight setup stay intact.

## V0.5 home redesign

- Premium full-screen landscape lobby with immersive system UI.
- No bottom navigation bar.
- Store, History, Profile, Wallet, Withdraw, Settings, Support, Rules & fees, and Home are all inside the **3-line menu**.
- Clear Home button automatically appears in the header on non-home sections.
- Lobby has **no scrolling**: all 2–10 player tables are visible at once on a normal landscape iPhone.
- 2–5 players = **green** tables.
- 6–8 players = **blue** tables.
- 9–10 players = **gold** tables.
- New premium felt texture, gold trim, card/chip art, shadows, responsive spacing, and smoother transitions.
- Table cards animate in and have a subtle press animation.
- Switching menu sections uses a smooth fade/slide transition.
- Display name stays in Profile instead of cluttering the home lobby.
- Delete Account remains in Settings and asks for confirmation first.

## Game / backend retained

- Real server-backed matchmaking for 2–10 players.
- Server-side deck and private cards.
- 10-chip boot and 5,000-chip cap.
- See / Pack / Chaal / Show / Play Again.
- Live backend default: `https://3-patti-ios.vercel.app`.
- Prototype 5% settled-pot fee remains disclosed in Rules & fees and the completed-round result breakdown; it is not cluttering the home lobby.

## Important prototype limitation

The wallet currently displays the planned `1 chip = ₹1` model, but real deposits, KYC, bank payouts, and withdrawals are **not connected** in this prototype. Those functions remain disabled until a properly licensed payment stack is connected for a permitted market.

The current Vercel backend also stores live room state in memory. That is suitable for prototype testing, not production scale. Before public scale, use persistent realtime room/session storage or a dedicated multiplayer service.

## Paste into Codespaces

Upload `three_patti_v05_premium_home.zip` to the root of the repo, then run:

```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v05_premium_home.zip
rm three_patti_v05_premium_home.zip
flutter pub get
git add .
git commit -m "Premium full-screen home v0.5"
git push
```

Vercel should redeploy because the backend version metadata is included.

## Test backend

```text
https://3-patti-ios.vercel.app/health
```

Expected after the Vercel redeploy:

```json
{"ok":true,"rooms":0,"version":"0.5.0"}
```

## TestFlight

The Flutter version is now **0.5.0+5**, so the next Codemagic/App Store Connect build should appear as Version 0.5.0, Build 5.

Test these first:

1. Home opens in landscape and uses the full screen.
2. All 2–10 player tables appear without scrolling.
3. Open the 3-line menu and visit Store, History, Profile, Wallet, Settings, etc.
4. Tap the Home icon in the header from any non-home section.
5. Join a 2-player room and confirm matchmaking still opens.
6. Test with a second iPhone to confirm the multiplayer flow.
