# 3 Patti Social v0.3 — Lobby Redesign Patch

This ZIP is designed to be extracted **into the root of your existing `3-patti-ios` GitHub repo**.
It intentionally does **not** include or overwrite your existing `ios/` folder, so your Apple bundle ID, signing setup, and TestFlight configuration stay intact.

## What this version changes

- Landscape-first / horizontal UI
- New dark green + gold casino-style lobby
- Table colors:
  - 2–5 players = GREEN
  - 6–8 players = BLUE
  - 9–10 players = GOLD
- No display name on the lobby; edit it in Profile
- Bottom navigation only: Store / History / Profile
- Tap the 3 Patti logo/title to return Home
- 3-line menu contains Wallet / Withdraw / Settings / Support / Rules & fees
- Delete Account is inside Settings and asks "Are you sure?" before clearing local prototype data
- Default live API URL: `https://3-patti-ios.vercel.app`
- Multiplayer flow retained: matchmaking, server-side deck, See / Pack / Chaal / Show / Play Again
- Prototype server applies a 5% table fee to a settled pot and returns the remaining chip payout to the winner
- Fee is not cluttering the lobby; it is disclosed in Rules & fees and in the result breakdown
- Version bumped to `0.3.0+3` for the next TestFlight build

## Important prototype limitation

The UI shows the planned `1 chip = ₹1` wallet model, but real deposits, KYC, bank payouts, and withdrawals are **not connected in this build**. Wallet and Withdraw screens clearly remain disabled until a properly licensed payment stack is connected for a permitted market.

Also, the current Vercel multiplayer backend keeps room state in memory. That is okay for an engineering prototype, but it is not production-safe because serverless instances can restart or split traffic. Before public scale, move live room state to a persistent realtime store or a dedicated multiplayer service.

## Paste this ZIP into Codespaces

Upload `three_patti_design_v03.zip` to the root of your repo, then run:

```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_design_v03.zip
rm three_patti_design_v03.zip
flutter pub get
git add .
git commit -m "Redesign 3 Patti lobby v0.3"
git push
```

Vercel should redeploy the backend automatically because `backend/` changed.

## Test backend

After Vercel finishes:

```text
https://3-patti-ios.vercel.app/health
```

Expected:

```json
{"ok":true,"rooms":0,"version":"0.3.0"}
```

## Build iOS

In Codemagic, build the `main` branch again with your existing App Store signing and App Store Connect publishing settings. Since the Flutter version is now `0.3.0+3`, it should appear in TestFlight as the next build.

## Files in this ZIP

- `lib/main.dart` — redesigned Flutter app + game table UI
- `backend/game.js` — shared game engine / matchmaking / 5% prototype table fee
- `backend/server.js` — local Node server
- `backend/api/index.js` — Vercel serverless entrypoint
- `backend/vercel.json` — Vercel rewrites
- `backend/package.json` — Node metadata
- `pubspec.yaml` — Flutter version `0.3.0+3`
- `design/lobby_reference.png` — the approved visual reference

