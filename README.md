# 3 Patti Social V1.0 — Real Game Table Redesign

Drop this ZIP into the root of the existing `3-patti-ios` repo. It intentionally does not overwrite `ios/`, so the existing Apple bundle ID/signing configuration stays in place.

## Visible table changes
- Full-screen game-room layout: no normal AppBar on the table
- Larger premium oval Teen Patti felt table with wood/gold rail
- Dealer host sits behind the top edge with a visible deck/hand
- Cards animate dealer → every player
- Player seats are arranged around the table with avatar, name, chips, and BLIND / SEEN / PACKED status
- 60-second countdown is a separate badge beside the ACTIVE PLAYER profile — never on the dealer
- Active player gets glow + TURN badge; local player also gets YOUR TURN feedback
- Incoming notification/control overlays do not stop the server-based timer; returning from background forces immediate resync
- No rupee sign on gameplay table; balances are CHIPS
- More colorful poker chips in the center pot
- Betting chips visibly fly player → pot
- Your three cards sit on the felt and flip open after See Cards
- Other users see your status as SEEN, but not your private cards
- Main action automatically changes BLIND → CHAAL after seeing cards
- BLIND uses 1x current amount; CHAAL uses 2x automatically
- Bottom controls are redesigned as game controls: SEE CARDS / PACK / BLIND-or-CHAAL / SHOW / SIDE SHOW
- Card, chip and winner audio hooks remain enabled
- Version `1.0.0+11`

## Install in Codespaces
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v10_real_game_table.zip
rm three_patti_v10_real_game_table.zip
flutter pub get
git add .
git commit -m "Full Teen Patti table redesign v1.0"
git push
```

After Vercel redeploys, `/health` should report `1.0.0`. Then build TestFlight Build 11.
